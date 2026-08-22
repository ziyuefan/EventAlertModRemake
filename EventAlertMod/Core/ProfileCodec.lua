--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/ProfileCodec
檔案: Core\ProfileCodec.lua

理念:
- 為目前職業 profile 提供可複製的 EAMAP1 JSON/Base64 分享格式。
- 匯出只包含白名單設定；匯入永遠重算 kind、unit 與 alert ID。

責任:
- 嚴格 JSON 編碼/解析、標準 Base64、Adler-32 完整性檢查。
- export、previewImport、applyImport 的交易式 API。

資料所有權:
- 不直接持有 SavedVariables；所有持久化寫入由 SavedVariables.applyProfileImport 完成。

邊界:
- 不執行 Lua 字串、不接受外部 function/userdata/metatable。
- 不讀取 Aura/Cooldown/UnitPower；遇到 Secret 值立即拒絕匯出。
- applyImport 在戰鬥中拒絕，避免 profile 變更觸發受保護 UI 結構更新。

Retail API 注意:
- Retail 12.x 優先使用 C_EncodingUtil.EncodeBase64/DecodeBase64。
- 純 Lua Base64 僅供離線驗證或 API 不可用時的降級，不代表客戶端能力簽收。
]]
local _, EAM = ...

local Util = EAM.Util or {}
local mathFloor = math.floor
local mathHuge = math.huge
local stringByte = string.byte
local stringChar = string.char
local stringSub = string.sub
local stringFind = string.find
local stringMatch = string.match
local stringFormat = string.format

local PREFIX = "EAMAP1:"
local CURRENT_SCHEMA = 1
local LIMITS = {
    encodedBytes = 262144,
    decodedBytes = 196608,
    maxDepth = 8,
    maxNodes = 16384,
    maxAlerts = 4096,
    maxPerModule = 1024,
    maxStringBytes = 16384,
}

local MODULES = {
    "playerAura",
    "targetAura",
    "spellCooldown",
    "itemCooldown",
    "groundEffect",
}

local MODULE_DEFINITIONS = {
    playerAura = { listName = "playerAuras", kind = "aura", unit = "player", idField = "spellID" },
    targetAura = { listName = "targetAuras", kind = "aura", unit = "target", idField = "spellID" },
    spellCooldown = { listName = "spellCooldowns", kind = "spellCooldown", unit = "player", idField = "spellID" },
    itemCooldown = { listName = "itemCooldowns", kind = "itemCooldown", unit = nil, idField = "itemID" },
    groundEffect = { listName = "groundEffects", kind = "groundEffect", unit = "player", idField = "spellID" },
}

local VALID_CLASSES = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true,
    PRIEST = true, DEATHKNIGHT = true, SHAMAN = true, MAGE = true,
    WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true,
    EVOKER = true,
}

local VALID_AURA_FILTERS = { HELPFUL = true, HARMFUL = true }
local VALID_DURATION_MODES = { AUTO = true, MANUAL = true }
local AURA_SOUND_KEYS = { "added", "applicationsIncreased", "removed" }
local COOLDOWN_BEHAVIOR_FIELDS = {
    "cooldownRemoveAura",
    "showSCDOutsideCombat",
    "glowSCDWhenUsable",
}

local Codec = {
    PREFIX = PREFIX,
    schema = CURRENT_SCHEMA,
    limits = LIMITS,
}
EAM.Modules.ProfileCodec = Codec

local function isSafeValue(value)
    return type(Util.isSafeValue) ~= "function" or Util.isSafeValue(value)
end

local function isSafeString(value, maxBytes)
    if type(Util.isSafeString) == "function" and not Util.isSafeString(value) then
        return false
    end
    if type(value) ~= "string" or #value == 0 or (maxBytes and #value > maxBytes) then
        return false
    end
    return not stringFind(value, "[%z\1-\31]")
end

local function isSafeInteger(value, minimum, maximum)
    if type(Util.isSafeNumber) == "function" then
        if not Util.isSafeNumber(value) then
            return false
        end
    elseif type(value) ~= "number" or value ~= value or value == mathHuge or value == -mathHuge then
        return false
    end
    if value % 1 ~= 0 then
        return false
    end
    return value >= minimum and (not maximum or value <= maximum)
end

local function isSafeFiniteNumber(value, minimum, maximum)
    if type(value) ~= "number" or value ~= value or value == mathHuge or value == -mathHuge then
        return false
    end
    if type(Util.isSafeNumber) == "function" and not Util.isSafeNumber(value) then
        return false
    end
    return value >= minimum and value <= maximum
end

local function isDenseArray(value, maximum)
    if type(value) ~= "table" or not isSafeValue(value) then
        return false, 0
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
            return false, 0
        end
        count = count + 1
        if key > count and key > (maximum or LIMITS.maxPerModule) then
            return false, 0
        end
    end
    for index = 1, count do
        if value[index] == nil then
            return false, 0
        end
    end
    return count <= (maximum or LIMITS.maxPerModule), count
end

local function escapeJSON(value)
    return string.gsub(value, '[%z\1-\31\\"]', function(character)
        if character == '"' then
            return '\\"'
        elseif character == "\\" then
            return "\\\\"
        elseif character == "\b" then
            return "\\b"
        elseif character == "\f" then
            return "\\f"
        elseif character == "\n" then
            return "\\n"
        elseif character == "\r" then
            return "\\r"
        elseif character == "\t" then
            return "\\t"
        end
        return stringFormat("\\u%04x", stringByte(character))
    end)
end

local function collectKeys(value)
    local keys = {}
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "string" then
            return nil, "nonStringObjectKey"
        end
        count = count + 1
        keys[count] = key
    end
    table.sort(keys)
    return keys
end

local function encodeJSON(value, stack, forcedArrays)
    local valueType = type(value)
    if value == nil then
        return "null"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        if not isSafeFiniteNumber(value, -9007199254740991, 9007199254740991) then
            return nil, "unsafeNumber"
        end
        return stringFormat("%.17g", value)
    elseif valueType == "string" then
        if not isSafeString(value, LIMITS.maxStringBytes) then
            return nil, "unsafeString"
        end
        return '"' .. escapeJSON(value) .. '"'
    elseif valueType ~= "table" or not isSafeValue(value) then
        return nil, "unsupportedValue"
    end

    stack = stack or {}
    if stack[value] then
        return nil, "cyclicTable"
    end
    stack[value] = true

    local forcedArray = forcedArrays and forcedArrays[value] == true
    local isArray = forcedArray
    local length = 0
    if not forcedArray then
        local count = 0
        local maximum = 0
        local allNumericKeys = true
        for key in pairs(value) do
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
                allNumericKeys = false
                break
            end
            count = count + 1
            if key > maximum then
                maximum = key
            end
        end
        isArray = allNumericKeys and count == maximum
        length = maximum
    else
        for key in pairs(value) do
            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
                stack[value] = nil
                return nil, "forcedArrayHasObjectKey"
            end
            if key > length then
                length = key
            end
        end
        for index = 1, length do
            if value[index] == nil then
                stack[value] = nil
                return nil, "sparseArray"
            end
        end
    end

    local result
    if isArray then
        local buffer = {}
        for index = 1, length do
            local encoded, reason = encodeJSON(value[index], stack, forcedArrays)
            if not encoded then
                stack[value] = nil
                return nil, reason
            end
            buffer[index] = encoded
        end
        result = "[" .. table.concat(buffer, ",") .. "]"
    else
        local keys, keyError = collectKeys(value)
        if not keys then
            stack[value] = nil
            return nil, keyError
        end
        local buffer = {}
        for index = 1, #keys do
            local key = keys[index]
            local encoded, reason = encodeJSON(value[key], stack, forcedArrays)
            if not encoded then
                stack[value] = nil
                return nil, reason
            end
            buffer[index] = '"' .. escapeJSON(key) .. '":' .. encoded
        end
        result = "{" .. table.concat(buffer, ",") .. "}"
    end

    stack[value] = nil
    return result
end

local function markPayloadArrays(payload, forcedArrays)
    for index = 1, #MODULES do
        local list = payload.modules[MODULES[index]]
        if list then
            forcedArrays[list] = true
        end
    end
end

local function markEnvelopeArrays(envelope, forcedArrays)
    forcedArrays[envelope.scope.modules] = true
    markPayloadArrays(envelope.payload, forcedArrays)
end

local function canonicalJSON(value, forcedArrays)
    local encoded, reason = encodeJSON(value, nil, forcedArrays or {})
    return encoded, reason
end

local function adler32(value)
    local a, b = 1, 0
    for index = 1, #value do
        a = (a + stringByte(value, index)) % 65521
        b = (b + a) % 65521
    end
    return stringFormat("%08x", b * 65536 + a)
end

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_REVERSE = {}
for index = 1, #BASE64_ALPHABET do
    BASE64_REVERSE[stringByte(BASE64_ALPHABET, index)] = index - 1
end

local function fallbackEncodeBase64(value)
    local output = {}
    local outputIndex = 0
    for index = 1, #value, 3 do
        local a = stringByte(value, index) or 0
        local b = stringByte(value, index + 1)
        local c = stringByte(value, index + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        outputIndex = outputIndex + 1
        output[outputIndex] = stringSub(BASE64_ALPHABET, mathFloor(n / 262144) + 1, mathFloor(n / 262144) + 1)
        outputIndex = outputIndex + 1
        output[outputIndex] = stringSub(BASE64_ALPHABET, mathFloor(n / 4096) % 64 + 1, mathFloor(n / 4096) % 64 + 1)
        outputIndex = outputIndex + 1
        output[outputIndex] = b and stringSub(BASE64_ALPHABET, mathFloor(n / 64) % 64 + 1, mathFloor(n / 64) % 64 + 1) or "="
        outputIndex = outputIndex + 1
        output[outputIndex] = c and stringSub(BASE64_ALPHABET, n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(output)
end

local function validateBase64(value)
    if type(value) ~= "string" or #value == 0 or #value > LIMITS.encodedBytes then
        return false, "base64Size"
    end
    local body, paddingText = stringMatch(value, "^([A-Za-z0-9+/]*)(=*)$")
    if #value % 4 ~= 0 or not body or #paddingText > 2 then
        return false, "base64Alphabet"
    end
    local padding = 0
    if stringSub(value, -1) == "=" then padding = padding + 1 end
    if stringSub(value, -2, -2) == "=" then padding = padding + 1 end
    if padding > 2 then
        return false, "base64Padding"
    end
    if padding > 0 and stringFind(stringSub(value, 1, #value - padding), "=") then
        return false, "base64Padding"
    end
    return true
end

local function fallbackDecodeBase64(value)
    local ok, reason = validateBase64(value)
    if not ok then
        return nil, reason
    end
    local output = {}
    local outputIndex = 0
    for index = 1, #value, 4 do
        local a = BASE64_REVERSE[stringByte(value, index)]
        local b = BASE64_REVERSE[stringByte(value, index + 1)]
        local cChar = stringByte(value, index + 2)
        local dChar = stringByte(value, index + 3)
        local c = cChar == stringByte("=", 1) and 0 or BASE64_REVERSE[cChar]
        local d = dChar == stringByte("=", 1) and 0 or BASE64_REVERSE[dChar]
        if a == nil or b == nil or c == nil or d == nil then
            return nil, "base64Alphabet"
        end
        local n = a * 262144 + b * 4096 + c * 64 + d
        outputIndex = outputIndex + 1
        output[outputIndex] = stringChar(mathFloor(n / 65536) % 256)
        if cChar ~= stringByte("=", 1) then
            outputIndex = outputIndex + 1
            output[outputIndex] = stringChar(mathFloor(n / 256) % 256)
        end
        if dChar ~= stringByte("=", 1) then
            outputIndex = outputIndex + 1
            output[outputIndex] = stringChar(n % 256)
        end
    end
    return table.concat(output)
end

local function encodeBase64(value)
    local encoding = rawget(_G, "C_EncodingUtil")
    if encoding and type(encoding.EncodeBase64) == "function" then
        local ok, encoded = pcall(encoding.EncodeBase64, value)
        if ok and type(encoded) == "string" then
            local valid = validateBase64(encoded)
            if valid then
                return encoded, "native"
            end
        end
    end
    return fallbackEncodeBase64(value), "fallback"
end

local function decodeBase64(value)
    local valid, reason = validateBase64(value)
    if not valid then
        return nil, reason
    end
    local encoding = rawget(_G, "C_EncodingUtil")
    if encoding and type(encoding.DecodeBase64) == "function" then
        local ok, decoded = pcall(encoding.DecodeBase64, value)
        if ok and type(decoded) == "string" then
            return decoded, "native"
        end
    end
    return fallbackDecodeBase64(value)
end

local Parser = {}

function Parser.new(input)
    return setmetatable({ input = input, position = 1, length = #input, depth = 0, nodes = 0 }, { __index = Parser })
end

function Parser:skipWhitespace()
    while self.position <= self.length do
        local byte = stringByte(self.input, self.position)
        if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
            return
        end
        self.position = self.position + 1
    end
end

function Parser:fail(reason)
    return nil, reason .. "@" .. tostring(self.position)
end

local function appendCodepoint(buffer, codepoint)
    if codepoint <= 0x7f then
        buffer[#buffer + 1] = stringChar(codepoint)
    elseif codepoint <= 0x7ff then
        buffer[#buffer + 1] = stringChar(0xc0 + mathFloor(codepoint / 0x40), 0x80 + codepoint % 0x40)
    elseif codepoint <= 0xffff then
        buffer[#buffer + 1] = stringChar(0xe0 + mathFloor(codepoint / 0x1000), 0x80 + mathFloor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    else
        buffer[#buffer + 1] = stringChar(0xf0 + mathFloor(codepoint / 0x40000), 0x80 + mathFloor(codepoint / 0x1000) % 0x40, 0x80 + mathFloor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    end
end

function Parser:parseString()
    if stringByte(self.input, self.position) ~= 34 then
        return self:fail("stringExpected")
    end
    self.position = self.position + 1
    local buffer = {}
    while self.position <= self.length do
        local byte = stringByte(self.input, self.position)
        self.position = self.position + 1
        if byte == 34 then
            local value = table.concat(buffer)
            if #value > LIMITS.maxStringBytes then
                return self:fail("stringTooLarge")
            end
            return value
        elseif byte == 92 then
            local escape = stringByte(self.input, self.position)
            self.position = self.position + 1
            local simple = { [34] = '"', [92] = "\\", [47] = "/", [98] = "\b", [102] = "\f", [110] = "\n", [114] = "\r", [116] = "\t" }
            if simple[escape] then
                buffer[#buffer + 1] = simple[escape]
            elseif escape == 117 then
                local hex = stringSub(self.input, self.position, self.position + 3)
                if #hex ~= 4 or not stringMatch(hex, "^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") then
                    return self:fail("unicodeEscape")
                end
                local codepoint = tonumber(hex, 16)
                self.position = self.position + 4
                if codepoint >= 0xd800 and codepoint <= 0xdbff then
                    if stringSub(self.input, self.position, self.position + 1) ~= "\\u" then
                        return self:fail("unicodeSurrogate")
                    end
                    local lowHex = stringSub(self.input, self.position + 2, self.position + 5)
                    if #lowHex ~= 4 or not stringMatch(lowHex, "^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") then
                        return self:fail("unicodeSurrogate")
                    end
                    local low = tonumber(lowHex, 16)
                    if low < 0xdc00 or low > 0xdfff then
                        return self:fail("unicodeSurrogate")
                    end
                    self.position = self.position + 6
                    codepoint = 0x10000 + (codepoint - 0xd800) * 0x400 + (low - 0xdc00)
                elseif codepoint >= 0xdc00 and codepoint <= 0xdfff then
                    return self:fail("unicodeSurrogate")
                end
                appendCodepoint(buffer, codepoint)
            else
                return self:fail("stringEscape")
            end
        elseif byte < 32 then
            return self:fail("controlCharacter")
        else
            buffer[#buffer + 1] = stringChar(byte)
        end
    end
    return self:fail("unterminatedString")
end

function Parser:parseNumber()
    local start = self.position
    if stringByte(self.input, self.position) == 45 then
        self.position = self.position + 1
    end
    local first = stringByte(self.input, self.position)
    if first == 48 then
        self.position = self.position + 1
        local nextByte = stringByte(self.input, self.position)
        if nextByte and nextByte >= 48 and nextByte <= 57 then
            return self:fail("leadingZero")
        end
    elseif first and first >= 49 and first <= 57 then
        repeat
            self.position = self.position + 1
            first = stringByte(self.input, self.position)
        until not first or first < 48 or first > 57
    else
        return self:fail("numberExpected")
    end
    if stringByte(self.input, self.position) == 46 then
        self.position = self.position + 1
        local digit = stringByte(self.input, self.position)
        if not digit or digit < 48 or digit > 57 then
            return self:fail("fractionExpected")
        end
        repeat
            self.position = self.position + 1
            digit = stringByte(self.input, self.position)
        until not digit or digit < 48 or digit > 57
    end
    local exponent = stringByte(self.input, self.position)
    if exponent == 69 or exponent == 101 then
        self.position = self.position + 1
        local sign = stringByte(self.input, self.position)
        if sign == 43 or sign == 45 then
            self.position = self.position + 1
        end
        local digit = stringByte(self.input, self.position)
        if not digit or digit < 48 or digit > 57 then
            return self:fail("exponentExpected")
        end
        repeat
            self.position = self.position + 1
            digit = stringByte(self.input, self.position)
        until not digit or digit < 48 or digit > 57
    end
    local numberValue = tonumber(stringSub(self.input, start, self.position - 1))
    if not numberValue or not isSafeValue(numberValue) or numberValue ~= numberValue or numberValue == mathHuge or numberValue == -mathHuge then
        return self:fail("unsafeNumber")
    end
    return numberValue
end

function Parser:parseValue()
    self:skipWhitespace()
    if self.position > self.length then
        return self:fail("valueExpected")
    end
    self.nodes = self.nodes + 1
    if self.nodes > LIMITS.maxNodes then
        return self:fail("nodeLimit")
    end
    local byte = stringByte(self.input, self.position)
    if byte == 34 then
        return self:parseString()
    elseif byte == 123 then
        return self:parseObject()
    elseif byte == 91 then
        return self:parseArray()
    elseif byte == 45 or (byte >= 48 and byte <= 57) then
        return self:parseNumber()
    elseif stringSub(self.input, self.position, self.position + 3) == "true" then
        self.position = self.position + 4
        return true
    elseif stringSub(self.input, self.position, self.position + 4) == "false" then
        self.position = self.position + 5
        return false
    elseif stringSub(self.input, self.position, self.position + 3) == "null" then
        self.position = self.position + 4
        return nil
    end
    return self:fail("invalidValue")
end

function Parser:parseArray()
    self.depth = self.depth + 1
    if self.depth > LIMITS.maxDepth then
        return self:fail("depthLimit")
    end
    self.position = self.position + 1
    local result = {}
    self:skipWhitespace()
    if stringByte(self.input, self.position) == 93 then
        self.position = self.position + 1
        self.depth = self.depth - 1
        return result
    end
    local index = 1
    while true do
        local value, reason = self:parseValue()
        if reason then
            return nil, reason
        end
        if value == nil then
            return self:fail("nullNotAllowed")
        end
        result[index] = value
        index = index + 1
        self:skipWhitespace()
        local byte = stringByte(self.input, self.position)
        if byte == 93 then
            self.position = self.position + 1
            self.depth = self.depth - 1
            return result
        elseif byte ~= 44 then
            return self:fail("arrayComma")
        end
        self.position = self.position + 1
        self:skipWhitespace()
    end
end

function Parser:parseObject()
    self.depth = self.depth + 1
    if self.depth > LIMITS.maxDepth then
        return self:fail("depthLimit")
    end
    self.position = self.position + 1
    local result = {}
    local seen = {}
    self:skipWhitespace()
    if stringByte(self.input, self.position) == 125 then
        self.position = self.position + 1
        self.depth = self.depth - 1
        return result
    end
    while true do
        local key, reason = self:parseString()
        if reason then
            return nil, reason
        end
        if seen[key] then
            return self:fail("duplicateKey")
        end
        seen[key] = true
        self:skipWhitespace()
        if stringByte(self.input, self.position) ~= 58 then
            return self:fail("objectColon")
        end
        self.position = self.position + 1
        local value, valueReason = self:parseValue()
        if valueReason or value == nil then
            return self:fail(valueReason or "nullNotAllowed")
        end
        result[key] = value
        self:skipWhitespace()
        local byte = stringByte(self.input, self.position)
        if byte == 125 then
            self.position = self.position + 1
            self.depth = self.depth - 1
            return result
        elseif byte ~= 44 then
            return self:fail("objectComma")
        end
        self.position = self.position + 1
        self:skipWhitespace()
    end
end

local function parseJSON(value)
    if type(value) ~= "string" or #value > LIMITS.decodedBytes then
        return nil, "jsonSize"
    end
    local parser = Parser.new(value)
    local result, reason = parser:parseValue()
    if reason then
        return nil, reason
    end
    parser:skipWhitespace()
    if parser.position <= parser.length then
        return nil, "trailingData"
    end
    return result
end

local function hasOnlyKeys(value, allowed)
    if type(value) ~= "table" or not isSafeValue(value) then
        return false, "objectRequired"
    end
    for key in pairs(value) do
        if type(key) ~= "string" or not allowed[key] then
            return false, "unknownField:" .. tostring(key)
        end
    end
    return true
end

local function normalizeSoundEntry(value)
    if type(value) ~= "table" then
        return nil, "soundObjectRequired"
    end
    local ok, reason = hasOnlyKeys(value, { soundFileID = true, soundFileName = true, outputChannel = true })
    if not ok then
        return nil, reason
    end
    local hasID = value.soundFileID ~= nil
    local hasName = value.soundFileName ~= nil
    if hasID == hasName then
        return nil, "soundAssetExclusive"
    end
    local normalized = {}
    if hasID then
        if not isSafeInteger(value.soundFileID, 1, 2147483647) then
            return nil, "soundFileIDInvalid"
        end
        normalized.soundFileID = value.soundFileID
    else
        if not isSafeString(value.soundFileName, 260) then
            return nil, "soundFileNameInvalid"
        end
        normalized.soundFileName = value.soundFileName
    end
    if value.outputChannel ~= nil then
        if not isSafeString(value.outputChannel, 32) then
            return nil, "outputChannelInvalid"
        end
        normalized.outputChannel = value.outputChannel
    end
    return normalized
end

local function normalizeAuraSound(value)
    if type(value) ~= "table" then
        return nil, "soundObjectRequired"
    end
    local ok, reason = hasOnlyKeys(value, {
        added = true,
        applicationsIncreased = true,
        removed = true,
    })
    if not ok then
        return nil, reason
    end
    local normalized = {}
    local count = 0
    for index = 1, #AURA_SOUND_KEYS do
        local trigger = AURA_SOUND_KEYS[index]
        if value[trigger] ~= nil then
            local entry, entryReason = normalizeSoundEntry(value[trigger])
            if not entry then
                return nil, entryReason
            end
            normalized[trigger] = entry
            count = count + 1
        end
    end
    if count == 0 then
        return nil, "soundEmpty"
    end
    return normalized
end

local function normalizeAuraRecord(record)
    local ok, reason = hasOnlyKeys(record, {
        spellID = true, enabled = true, fromPlayer = true, catalogScope = true, auraFilter = true,
        showStacks = true, showName = true, showCountdown = true, priority = true,
        sound = true,
    })
    if not ok then
        return nil, reason
    end
    if not isSafeInteger(record.spellID, 1, 2147483647) then
        return nil, "spellIDInvalid"
    end
    local normalized = {
        spellID = record.spellID,
        enabled = record.enabled ~= false,
        fromPlayer = record.fromPlayer == true,
        showStacks = record.showStacks ~= false,
        showName = record.showName ~= false,
        showCountdown = record.showCountdown ~= false,
        priority = 10,
    }
    if record.enabled ~= nil and type(record.enabled) ~= "boolean" then return nil, "enabledInvalid" end
    if record.fromPlayer ~= nil and type(record.fromPlayer) ~= "boolean" then return nil, "fromPlayerInvalid" end
    if record.catalogScope ~= nil then
        if record.catalogScope ~= EAM.Constants.AURA_CATALOG_SCOPE_SELF
            and record.catalogScope ~= EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS then
            return nil, "catalogScopeInvalid"
        end
        normalized.catalogScope = record.catalogScope
    end
    if record.showStacks ~= nil and type(record.showStacks) ~= "boolean" then return nil, "showStacksInvalid" end
    if record.showName ~= nil and type(record.showName) ~= "boolean" then return nil, "showNameInvalid" end
    if record.showCountdown ~= nil and type(record.showCountdown) ~= "boolean" then return nil, "showCountdownInvalid" end
    if record.auraFilter ~= nil then
        if type(record.auraFilter) ~= "string" or not VALID_AURA_FILTERS[record.auraFilter] then return nil, "auraFilterInvalid" end
        normalized.auraFilter = record.auraFilter
    end
    if record.priority ~= nil then
        if not isSafeInteger(record.priority, 1, 20) then return nil, "priorityInvalid" end
        normalized.priority = record.priority
    end
    if record.sound ~= nil then
        local sound, soundReason = normalizeAuraSound(record.sound)
        if not sound then return nil, soundReason end
        normalized.sound = sound
    end
    return normalized
end

local function normalizeModuleRecord(moduleName, record)
    local definition = MODULE_DEFINITIONS[moduleName]
    if not definition then
        return nil, "unknownModule"
    end
    if moduleName == "playerAura" or moduleName == "targetAura" then
        return normalizeAuraRecord(record)
    end
    local allowed = { enabled = true }
    allowed[definition.idField] = true
    if moduleName == "groundEffect" then
        allowed.durationMode = true
        allowed.manualDuration = true
    elseif moduleName == "spellCooldown" then
        for index = 1, #COOLDOWN_BEHAVIOR_FIELDS do
            allowed[COOLDOWN_BEHAVIOR_FIELDS[index]] = true
        end
    end
    local ok, reason = hasOnlyKeys(record, allowed)
    if not ok then return nil, reason end
    local id = record[definition.idField]
    if not isSafeInteger(id, 1, 2147483647) then
        return nil, definition.idField .. "Invalid"
    end
    if record.enabled ~= nil and type(record.enabled) ~= "boolean" then return nil, "enabledInvalid" end
    local normalized = { [definition.idField] = id, enabled = record.enabled ~= false }
    if moduleName == "groundEffect" then
        normalized.durationMode = record.durationMode or "AUTO"
        if not VALID_DURATION_MODES[normalized.durationMode] then return nil, "durationModeInvalid" end
        normalized.manualDuration = record.manualDuration or 8
        if type(normalized.manualDuration) ~= "number" or normalized.manualDuration ~= normalized.manualDuration or normalized.manualDuration < 0.1 or normalized.manualDuration > 3600 then
            return nil, "manualDurationInvalid"
        end
    elseif moduleName == "spellCooldown" then
        for index = 1, #COOLDOWN_BEHAVIOR_FIELDS do
            local field = COOLDOWN_BEHAVIOR_FIELDS[index]
            if record[field] ~= nil then
                if type(record[field]) ~= "boolean" then
                    return nil, "cooldownBehaviorInvalid"
                end
                normalized[field] = record[field]
            end
        end
    end
    return normalized
end

local function normalizeModuleSelection(value)
    if value == nil then
        local result = {}
        for index = 1, #MODULES do result[index] = MODULES[index] end
        return result
    end
    local valid, count = isDenseArray(value, #MODULES)
    if not valid or count == 0 then return nil, "modulesInvalid" end
    local result, seen = {}, {}
    for index = 1, count do
        local moduleName = value[index]
        if type(moduleName) ~= "string" or not MODULE_DEFINITIONS[moduleName] or seen[moduleName] then
            return nil, "moduleInvalid"
        end
        seen[moduleName] = true
        result[index] = moduleName
    end
    table.sort(result)
    return result
end

local function currentClassToken()
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    local classToken = saved and saved.getActiveClassToken and saved.getActiveClassToken()
    return VALID_CLASSES[classToken] and classToken or nil
end

local function getList(definition, classToken)
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if not saved or type(saved.getAlertList) ~= "function" then return nil end
    return saved.getAlertList(definition.kind, definition.unit, classToken)
end

local function exportRecord(moduleName, alert)
    if type(alert) ~= "table" or not isSafeValue(alert) then return nil, "alertRestricted" end
    local definition = MODULE_DEFINITIONS[moduleName]
    local id = alert[definition.idField]
    if not isSafeInteger(id, 1, 2147483647) then return nil, "alertIDInvalid" end
    if moduleName == "playerAura" or moduleName == "targetAura" then
        local record = normalizeAuraRecord({
            spellID = id,
            enabled = alert.enabled ~= false,
            fromPlayer = alert.fromPlayer == true,
            catalogScope = alert.catalogScope,
            auraFilter = alert.auraFilter,
            showStacks = alert.showStacks ~= false,
            showName = alert.showName ~= false,
            showCountdown = alert.showCountdown ~= false,
            priority = alert.priority or 10,
            sound = alert.sound,
        })
        return record
    elseif moduleName == "groundEffect" then
        return normalizeModuleRecord(moduleName, {
            spellID = id,
            enabled = alert.enabled ~= false,
            durationMode = alert.durationMode,
            manualDuration = alert.manualDuration,
        })
    elseif moduleName == "spellCooldown" then
        local record = {
            spellID = id,
            enabled = alert.enabled ~= false,
        }
        for index = 1, #COOLDOWN_BEHAVIOR_FIELDS do
            local field = COOLDOWN_BEHAVIOR_FIELDS[index]
            if type(alert[field]) == "boolean" then
                record[field] = alert[field]
            end
        end
        return normalizeModuleRecord(moduleName, record)
    end
    return normalizeModuleRecord(moduleName, { [definition.idField] = id, enabled = alert.enabled ~= false })
end

local function buildPayload(classToken, modules)
    local payload = { modules = {} }
    local total = 0
    for index = 1, #modules do
        local moduleName = modules[index]
        local definition = MODULE_DEFINITIONS[moduleName]
        local list = getList(definition, classToken)
        if not list or not isSafeValue(list) then return nil, "alertListRestricted" end
        local records = {}
        local count = 0
        for _, alert in pairs(list) do
            local record, reason = exportRecord(moduleName, alert)
            if not record then return nil, reason end
            count = count + 1
            if count > LIMITS.maxPerModule then return nil, "moduleLimit" end
            records[count] = record
        end
        table.sort(records, function(left, right)
            local leftID = left[definition.idField]
            local rightID = right[definition.idField]
            return leftID < rightID
        end)
        payload.modules[moduleName] = records
        total = total + count
    end
    if total > LIMITS.maxAlerts then return nil, "alertLimit" end
    return payload, total
end

local function buildEnvelope(classToken, modules, payload)
    local payloadJSON, payloadReason = canonicalJSON(payload, (function()
        local forced = {}
        markPayloadArrays(payload, forced)
        return forced
    end)())
    if not payloadJSON then return nil, payloadReason end
    local envelope = {
        type = "EAM_ALERT_PROFILE",
        schema = CURRENT_SCHEMA,
        addonSchema = EAM.Constants.SCHEMA_VERSION,
        scope = { classToken = classToken, modules = modules },
        payload = payload,
        payloadBytes = #payloadJSON,
        checksum = { algorithm = "adler32", value = adler32(payloadJSON) },
    }
    local forced = {}
    markEnvelopeArrays(envelope, forced)
    return envelope, canonicalJSON(envelope, forced)
end

local function validateEnvelope(envelope)
    local ok, reason = hasOnlyKeys(envelope, { type = true, schema = true, addonSchema = true, scope = true, payload = true, payloadBytes = true, checksum = true })
    if not ok then return nil, reason end
    if envelope.type ~= "EAM_ALERT_PROFILE" or envelope.schema ~= CURRENT_SCHEMA or envelope.addonSchema ~= EAM.Constants.SCHEMA_VERSION then
        return nil, "schemaUnsupported"
    end
    ok, reason = hasOnlyKeys(envelope.scope, { classToken = true, modules = true })
    if not ok or type(envelope.scope.classToken) ~= "string" or not VALID_CLASSES[envelope.scope.classToken] then return nil, "scopeInvalid" end
    local modulesValid, moduleCount = isDenseArray(envelope.scope.modules, #MODULES)
    if not modulesValid or moduleCount == 0 then return nil, "scopeModulesInvalid" end
    local selected = {}
    for index = 1, moduleCount do
        local moduleName = envelope.scope.modules[index]
        if type(moduleName) ~= "string" or not MODULE_DEFINITIONS[moduleName] or selected[moduleName] then return nil, "scopeModuleInvalid" end
        selected[moduleName] = true
    end
    ok, reason = hasOnlyKeys(envelope.payload, { modules = true })
    if not ok or type(envelope.payload.modules) ~= "table" then return nil, "payloadInvalid" end
    for moduleName in pairs(envelope.payload.modules) do
        if not selected[moduleName] then return nil, "payloadModuleOutOfScope" end
    end
    local total = 0
    for index = 1, moduleCount do
        local moduleName = envelope.scope.modules[index]
        local records = envelope.payload.modules[moduleName]
        local recordsValid, count = isDenseArray(records, LIMITS.maxPerModule)
        if not recordsValid then return nil, "recordsInvalid" end
        local seen = {}
        for recordIndex = 1, count do
            local normalized, recordReason = normalizeModuleRecord(moduleName, records[recordIndex])
            if not normalized then return nil, recordReason end
            local definition = MODULE_DEFINITIONS[moduleName]
            local id = normalized[definition.idField]
            if seen[id] then return nil, "duplicateAlertID" end
            seen[id] = true
            records[recordIndex] = normalized
        end
        total = total + count
    end
    if total > LIMITS.maxAlerts then return nil, "alertLimit" end
    local payloadJSON, payloadReason = canonicalJSON(envelope.payload, (function()
        local forced = {}
        markPayloadArrays(envelope.payload, forced)
        return forced
    end)())
    if not payloadJSON then return nil, payloadReason end
    if envelope.payloadBytes ~= #payloadJSON then return nil, "payloadBytesMismatch" end
    ok, reason = hasOnlyKeys(envelope.checksum, { algorithm = true, value = true })
    if not ok or envelope.checksum.algorithm ~= "adler32" or not isSafeString(envelope.checksum.value, 8) or envelope.checksum.value ~= adler32(payloadJSON) then return nil, "checksumMismatch" end
    table.sort(envelope.scope.modules)
    return envelope
end

local function decodeEnvelope(encoded)
    if type(encoded) ~= "string" then return nil, "payloadType" end
    encoded = stringMatch(encoded, "^%s*(.-)%s*$")
    if stringSub(encoded, 1, #PREFIX) ~= PREFIX then return nil, "prefixMissing" end
    local base64 = stringSub(encoded, #PREFIX + 1)
    if #base64 > LIMITS.encodedBytes then return nil, "encodedSize" end
    local json, backendOrReason = decodeBase64(base64)
    if not json then return nil, backendOrReason end
    if #json > LIMITS.decodedBytes then return nil, "decodedSize" end
    local envelope, parseReason = parseJSON(json)
    if not envelope then return nil, parseReason end
    local validated, validateReason = validateEnvelope(envelope)
    if not validated then return nil, validateReason end
    validated._encodingBackend = backendOrReason
    return validated
end

local function compareRecord(moduleName, record, classToken)
    local definition = MODULE_DEFINITIONS[moduleName]
    local list = getList(definition, classToken)
    local id = record[definition.idField]
    local key = EAM.Modules.SavedVariables.buildAlertID(definition.kind, definition.unit, definition.kind == "itemCooldown" and nil or id, definition.kind == "itemCooldown" and id or nil)
    local existing = list and list[key]
    if not existing then return "add" end
    local exported = exportRecord(moduleName, existing)
    if not exported then return "conflict" end
    local leftJSON = canonicalJSON(record)
    local rightJSON = canonicalJSON(exported)
    return leftJSON == rightJSON and "unchanged" or "update"
end

function Codec.exportProfile(moduleSelection)
    local classToken = currentClassToken()
    if not classToken then return nil, "classUnavailable" end
    local modules, reason = normalizeModuleSelection(moduleSelection)
    if not modules then return nil, reason end
    local payload, alertCountOrReason = buildPayload(classToken, modules)
    if not payload then return nil, alertCountOrReason end
    local envelope, json = buildEnvelope(classToken, modules, payload)
    if not envelope or not json then return nil, json or "jsonEncodeFailed" end
    if #json > LIMITS.decodedBytes then return nil, "decodedSize" end
    local base64, backend = encodeBase64(json)
    local result = PREFIX .. base64
    if #result > LIMITS.encodedBytes then return nil, "encodedSize" end
    return result, {
        classToken = classToken,
        modules = modules,
        alertCount = alertCountOrReason,
        encodingBackend = backend,
        payloadBytes = envelope.payloadBytes,
        checksum = envelope.checksum.value,
    }
end

function Codec.previewImport(encoded, options)
    local envelope, reason = decodeEnvelope(encoded)
    if not envelope then return nil, reason end
    options = type(options) == "table" and options or {}
    local targetClassToken = options.targetClassToken or envelope.scope.classToken
    if not VALID_CLASSES[targetClassToken] then return nil, "targetClassInvalid" end
    if targetClassToken ~= envelope.scope.classToken and options.targetClassToken == nil then return nil, "targetClassExplicitRequired" end
    local counts = { add = 0, update = 0, unchanged = 0, conflict = 0, remove = 0 }
    local total = 0
    for index = 1, #envelope.scope.modules do
        local moduleName = envelope.scope.modules[index]
        local records = envelope.payload.modules[moduleName]
        local definition = MODULE_DEFINITIONS[moduleName]
        local list = getList(definition, targetClassToken)
        local seen = {}
        for recordIndex = 1, #records do
            local record = records[recordIndex]
            local status = compareRecord(moduleName, record, targetClassToken)
            counts[status] = counts[status] + 1
            seen[record[definition.idField]] = true
            total = total + 1
        end
        if options.mode == "replace" and list then
            for key, existing in pairs(list) do
                local exported = exportRecord(moduleName, existing)
                local existingID = exported and exported[definition.idField]
                if existingID and not seen[existingID] then counts.remove = counts.remove + 1 end
            end
        end
    end
    local payloadJSON = canonicalJSON(envelope.payload, (function()
        local forced = {}
        markPayloadArrays(envelope.payload, forced)
        return forced
    end)())
    return {
        envelope = envelope,
        payload = envelope.payload,
        targetClassToken = targetClassToken,
        counts = counts,
        alertCount = total,
        revisionAtPreview = EAM.db and EAM.db.revision or 0,
        fingerprint = adler32(payloadJSON or ""),
        consumed = false,
    }
end

function Codec.applyImport(plan, mode, targetClassToken)
    if type(plan) ~= "table" or plan.consumed == true or type(plan.payload) ~= "table" then return nil, "planInvalid" end
    if mode ~= "merge" and mode ~= "replace" then return nil, "modeInvalid" end
    if EAM.API and EAM.API.InCombatLockdown and EAM.API.InCombatLockdown() then return nil, "combatDeferred" end
    if not EAM.db or EAM.db.revision ~= plan.revisionAtPreview then return nil, "stalePreview" end
    targetClassToken = targetClassToken or plan.targetClassToken
    if targetClassToken ~= plan.targetClassToken or not VALID_CLASSES[targetClassToken] then return nil, "targetClassInvalid" end
    local payloadJSON = canonicalJSON(plan.payload, (function()
        local forced = {}
        markPayloadArrays(plan.payload, forced)
        return forced
    end)())
    if adler32(payloadJSON or "") ~= plan.fingerprint then return nil, "planChanged" end
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if not saved or type(saved.applyProfileImport) ~= "function" then return nil, "savedVariablesUnavailable" end
    local ok, status, report = saved.applyProfileImport(targetClassToken, plan.payload.modules, mode)
    if not ok then return nil, status end
    plan.consumed = true
    return report or { status = status }
end

function Codec.decodeForTest(encoded)
    return decodeEnvelope(encoded)
end

function Codec.getLimits()
    return LIMITS
end

