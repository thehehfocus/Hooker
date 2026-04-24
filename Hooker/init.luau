--!strict
local Module = {}

local Signal = require(script.Signal)

-------------------------
--== Functions hooks ==--
-------------------------

local FunctionHookClass = {}
FunctionHookClass.__index = FunctionHookClass

type function GetParameters(ty: type)
	local result = types.newfunction(ty:parameters())
	return result
end
type AnyFunction = (...any) -> any
type FunctionHook<A = AnyFunction, T = {any}> = setmetatable<{
	TargetTable: T?,
	Key: any,
	OriginalFunction: A,
	CurrentFunction: A,

	OnCall: Signal.Signal<...any>,
	Replace: (self: FunctionHook<A,T>, Func: A) -> (),
	
	Call: A,
}, typeof(FunctionHookClass)>

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

type TableHook<T = {any}> = setmetatable<{
	Table: T,
	
	OnRead: Signal.Signal<any>,
	OnWrite: Signal.Signal<any, any>,
	
	RawGet: (self: TableHook<T>, Key: any) -> any,
	RawSet: (self: TableHook<T>, Key: any, Value: any) -> (),
	
	[string]: any,
}, typeof(TableHookClass)>

-- Creates a new table hook, fires on read and write, use Proxy (second return).
function Module.HookTable<T>(TargetTable: T) : (TableHook<T>, T)
	local NewHook = setmetatable({}, TableHookClass) :: TableHook<T>
	NewHook._OriginalTable = TargetTable
	
	NewHook.OnRead = Signal()
	NewHook.OnWrite = Signal()
	
	local Proxy = newproxy(true)
	local Metatable = getmetatable(Proxy)
	Metatable.__index = function(_, Key)
		NewHook.OnRead:Fire(Key)
		return (TargetTable::any)[Key]
	end
	Metatable.__newindex = function(_, Key, Value)
		(TargetTable::any)[Key] = Value
		NewHook.OnWrite:Fire(Key, Value)
	end
	
	NewHook.Table = Proxy
	
	return NewHook, Proxy
end
-- Returns a value from the original table, bypassing .OnRead
function TableHookClass.RawGet(self: TableHook, Key: any) : any
	return self._OriginalTable[Key]
end
-- Sets a value in the original table, bypassing .OnWrite
function TableHookClass.RawSet(self: TableHook, Key: any, Value: any)
	self._OriginalTable[Key] = Value
end

-------------------------
----== Value hooks ==----
-------------------------

local ValueHookClass = {}
ValueHookClass.__index = ValueHookClass

type ValueHook<T> = setmetatable<{
	_Value: T,
	Freezed: boolean?,
	OnChange: Signal.Signal<(T, T)>,
	
	ToggleFreeze: (ValueHook<T>, boolean?) -> (),
	Set: (ValueHook<T>, T) -> (),
	Get: (ValueHook<T>) -> T,
}, typeof(ValueHookClass)>

-- Creates a new value hook, use methods to change value.
function Module.HookValue<T>(TargetValue: T, Freeze: boolean?) : ValueHook<T>
	local NewHook = setmetatable({}, ValueHookClass) :: ValueHook<T>
	NewHook._Value = TargetValue
	NewHook.OnChange = Signal()
	NewHook.Freezed = Freeze
	
	return NewHook
end
-- Gets the value
function ValueHookClass.Get<T>(self: ValueHook<T>) : T
	return self._Value
end
-- Sets the value, if freezed, will warn and return.
function ValueHookClass.Set<T>(self: ValueHook<T>, NewValue: T)
	if self.Freezed then
		warn("Hook is freezed")
		warn(self)
		return
	end
	
	self.OnChange:Fire(NewValue, self._Value)
	self._Value = NewValue
end
-- Toggles the freezed state. If true, will not allow changes.
function ValueHookClass.ToggleFreeze<T>(self: ValueHook<T>, Value: boolean?)
	self.Freezed = Value
end

return Module
