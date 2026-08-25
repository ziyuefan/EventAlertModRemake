--[[ $Id$ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 8
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {__index = function(tbl, key) key = tostring(key); tbl[key] = {} return tbl[key] end}

-- Create a new CallbackHandler instance
function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	UnregisterAllName = UnregisterAllName or "UnregisterAllCallbacks"

	local events = setmetatable({}, meta)
	local registry = { recurse = 0, events = events }

	-- Fire an event to all registered callbacks
	local function Fire(self, eventname, ...)
		if not rawget(events, eventname) or not next(events[eventname]) then return end
		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		for self_or_func, method in pairs(events[eventname]) do
			if type(method) == "string" then
				if type(self_or_func[method]) == "function" then
					self_or_func[method](self_or_func, eventname, ...)
				end
			elseif type(method) == "function" then
				method(eventname, ...)
			end
		end

		registry.recurse = oldrecurse
		if registry.insertQueue and oldrecurse == 0 then
			for _, v in ipairs(registry.insertQueue) do
				events[v[1]][v[2]] = v[3]
			end
			registry.insertQueue = nil
		end
	end

	-- Register a callback
	local function Register(self, eventname, method, ...)
		if type(eventname) ~= "string" then
			error("Usage: " .. RegisterName .. "(eventname, method, [arg]): 'eventname' - string expected.", 2)
		end
		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: " .. RegisterName .. "(eventname, method, [arg]): 'method' - string or function expected.", 2)
		end

		local regObj
		if type(method) == "string" then
			if type(self) ~= "table" and type(self) ~= "userdata" then
				error("Usage: " .. RegisterName .. "(eventname, method, [arg]): 'self' - table expected when method is string.", 2)
			end
			regObj = self
		else
			regObj = select(1, ...) or method
		end

		if registry.recurse ~= 0 then
			registry.insertQueue = registry.insertQueue or {}
			table.insert(registry.insertQueue, {eventname, regObj, method})
		else
			events[eventname][regObj] = method
		end
	end

	-- Unregister a callback
	local function Unregister(self, eventname)
		if type(eventname) ~= "string" then
			error("Usage: " .. UnregisterName .. "(eventname): 'eventname' - string expected.", 2)
		end
		if rawget(events, eventname) then
			events[eventname][self] = nil
		end
	end

	-- Unregister all callbacks
	local function UnregisterAll(self)
		for _, funcs in pairs(events) do
			funcs[self] = nil
		end
	end

	target[RegisterName] = Register
	target[UnregisterName] = Unregister
	if UnregisterAllName then
		target[UnregisterAllName] = UnregisterAll
	end
	target.Fire = Fire

	return registry
end
