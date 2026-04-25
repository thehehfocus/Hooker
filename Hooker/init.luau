--!strict
local Module = {}

local Signal = require(script.Signal)

local function GetTrace(Warning: string)
	local Result = `Warning "{Warning}" occured. Stack trace: \n`
	local Line = ""
	local i = 2
	while Line do
		Line = debug.info(i, "l")
		local Name = debug.info(i, "s")
		if Line then Result = `{Result} At line {Line}, in script {Name} \n` end
		i+=1
	end
	return Result
end

-------------------------
--== Functions hooks ==--
-------------------------

local FunctionHookClass = {}
FunctionHookClass.__index = FunctionHookClass

type FunctionHook<A = () -> (), T = {any}> = {
	TargetTable: T?,
	Key: any,
	OriginalFunction: A,
	CurrentFunction: A,

	OnCall: Signal.Signal<...any>,
	CannotCall: boolean?,
	
	Call: A,
	Replace: (self: FunctionHook<A,T>, Func: A) -> (),
}

-- Creates a new function hook
function Module.HookFunction<A, T>(TargetFunction: A & (...any) -> any, TargetTable: T?)
	local Key = nil
	if TargetTable then
		for i,v in pairs(TargetTable) do
			if v == TargetFunction then
				Key = i
				break
			end
		end
		if not Key then
			error(`{TargetFunction} is not a valid function`)
		end
	end
	
	local NewHook = setmetatable({}, FunctionHookClass) :: FunctionHook<A, T>
	NewHook.TargetTable = TargetTable
	NewHook.Key = Key
	NewHook.OriginalFunction = TargetFunction
	NewHook:Replace(NewHook.OriginalFunction)
	
	NewHook.OnCall = Signal()
	NewHook.Call = function(...)
		return (NewHook.CurrentFunction::any)(...)
	end
	
	return NewHook
end
-- Replaces the executed function with the new one, if hook has table specified, it will change the function in the table.
function FunctionHookClass.Replace<A, T>(self: FunctionHook<A, T>, Function: A)
	if self.TargetTable then
		local PrevFunc = (self.TargetTable::any)[self.Key]
		if PrevFunc ~= self.OriginalFunction and PrevFunc ~= self.CurrentFunction then
			error(`{self.Key} has changed.`)
		end
	end
	
	local HookedFunc = function(...)
		if self.CannotCall then
			warn(self)
			warn(GetTrace(`Function is not callable.`))
			return
		end
		
		self.OnCall:Fire();
		return (Function::any)(...)
	end
	
	self.CurrentFunction = HookedFunc;
	
	if self.TargetTable then
		(self.TargetTable::any)[self.Key] = HookedFunc
	end
	
	return self
end

-------------------------
----== Table hooks ==----
-------------------------

local TableHookClass = {}
TableHookClass.__index = TableHookClass

type TableHook<T = {any}> = {
	Table: T,
	Freezed: boolean?,
	ReadOnlyKeys: {[any]: boolean?},
	
	OnRead: Signal.Signal<any>,
	OnWrite: Signal.Signal<any, any>,
	ReadFunction: (Table: T, Key: any) -> any,
	WriteFunction: (Table: T, Key: any, Value: any) -> any,
	
	RawGet: (self: TableHook<T>, Key: any) -> any,
	RawSet: (self: TableHook<T>, Key: any, Value: any) -> (),
	
	ToggleFreeze: (self: TableHook<T>, State: boolean?) -> (),
	ToggleReadOnlyKey: (self: TableHook<T>, Key: any, State: boolean?) -> (),
	
	GetValues: (self: TableHook<T>) -> T,
	
	[string]: any,
}

-- Creates a new table hook, fires on read and write, use Proxy (second return).
function Module.HookTable<T>(TargetTable: T) : (TableHook<T>, T)
	local NewHook = setmetatable({}, TableHookClass) :: TableHook<T>
	NewHook._OriginalTable = TargetTable
	NewHook.ReadOnlyKeys = {}
	
	NewHook.OnRead = Signal()
	NewHook.OnWrite = Signal()
	
	local Proxy = newproxy(true)
	local Metatable = getmetatable(Proxy)
	Metatable.__index = function(_, Key)
		NewHook.OnRead:Fire(Key)
		if NewHook.ReadFunction then
			return NewHook.ReadFunction(TargetTable, Key)
		end
		return (TargetTable::any)[Key]
	end
	Metatable.__newindex = function(_, Key, Value)
		if NewHook.ReadOnlyKeys[Key] then
			warn(NewHook)
			warn(GetTrace(`Attempt to modify a read-only key: {Key}`))
			return
		end
		if NewHook.Freezed then
			warn(NewHook)
			warn(GetTrace(`Attempt to modify a frozen table.`))
			return
		end
		
		NewHook.OnWrite:Fire(Key, Value)
		if NewHook.WriteFunction then
			return NewHook.WriteFunction(TargetTable, Key, Value)
		end
		(TargetTable::any)[Key] = Value
	end
	
	NewHook.Table = Proxy
	
	return NewHook, Proxy
end
-- Returns a value from the original table, bypassing .OnRead
function TableHookClass.RawGet(self: TableHook, Key: any) : any
	return self._OriginalTable[Key]
end
-- Sets a value in the original table, bypassing .OnWrite and Freeze
function TableHookClass.RawSet(self: TableHook, Key: any, Value: any)
	self._OriginalTable[Key] = Value
end
-- Gets the values of the table
function TableHookClass.GetValues(self: TableHook) : any
	return self._OriginalTable
end
-- Freezes the table, prevents any changes
function TableHookClass.ToggleFreeze(self: TableHook, Value: boolean?)
	self.Freezed = Value
end
-- Sets a key to read-only
function TableHookClass.ToggleReadOnlyKey(self: TableHook, Key: any, Value: boolean?)
	self.ReadOnlyKeys[Key] = Value and true or nil
end

-------------------------
----== Value hooks ==----
-------------------------

local ValueHookClass = {}
ValueHookClass.__index = ValueHookClass

type ValueHook<T> = {
	Value: T, -- Setting/Getting it explicitly will be equal to Rawset/Rawget
	Freezed: boolean?,
	OnChange: Signal.Signal<(T, T)>,
	
	SetFunction: (T) -> T?,
	GetFunction: (T) -> T?,
	
	ToggleFreeze: (ValueHook<T>, boolean?) -> (),
	Set: (ValueHook<T>, T) -> (),
	Get: (ValueHook<T>) -> T,
}

-- Creates a new value hook, use methods to change value.
function Module.HookValue<T>(TargetValue: T, Freeze: boolean?) : ValueHook<T>
	local NewHook = setmetatable({}, ValueHookClass) :: ValueHook<T>
	NewHook.Value = TargetValue
	NewHook.OnChange = Signal()
	NewHook.Freezed = Freeze
	
	return NewHook
end
-- Gets the value
function ValueHookClass.Get<T>(self: ValueHook<T>) : T
	return self.GetFunction and self.GetFunction(self.Value) or self.___Value
end
-- Sets the value, if freezed, will warn and return.
function ValueHookClass.Set<T>(self: ValueHook<T>, NewValue: T)
	if self.Freezed then
		warn(self)
		warn(GetTrace(`Attempt to modify a frozen value.`))
		return
	end
	
	self.OnChange:Fire(NewValue, self.Value)
	
	self.Value = self.SetFunction and self.SetFunction(NewValue) or NewValue
end
-- Toggles the freezed state. If true, will not allow changes.
function ValueHookClass.ToggleFreeze<T>(self: ValueHook<T>, Value: boolean?)
	self.Freezed = Value
end

return Module
