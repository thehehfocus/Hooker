# Hooker
Simple module to create hooks and reactive values without making a mess.

## Installation
Just copy the Hooker folder contents.

## Usage

### Hooking a table function:
```lua
local Table = {
	DoSomething = function()
		print("executed")
	end,
} 

local AnotherHook = Hooker.HookFunction(Table.DoSomething, Table)
AnotherHook.OnCall:Connect(function(...)
	print("Hello world!")
end)
AnotherHook:Replace(function(...)
	print("Hello world2!")
	return AnotherHook.OriginalFunction(...)
end)

Table.DoSomething() -- Prints "Hello world2!", then "executed", then "Hello world!"
```

### Creating a hook function:
```lua
local Table = {
	DoSomething = function()
		print("executed")
	end,
}

local HookTwo = Hooker.HookFunction(Table.DoSomething)
HookTwo:Replace(function(...)
	print("Hello world!")
	return HookTwo.OriginalFunction(...)
end)
HookTwo.Call() -- Prints "Hello world!", then "executed"
```

### Making a reactive table:
```lua
local Table = {
	DoSomething = function()
		print("executed")
	end,
}

local NewHook, Table = Hooker.HookTable(Table)
NewHook.OnRead:Connect(function(Key)
	print("read ".. Key)
end)
NewHook.OnWrite:Connect(function(Key, Value)
	print("write ".. Key.. " = ".. Value)
end)

NewHook.WriteFunction = function(self, key, value)
	self[key] = value * 2
end

Table.a = 5 -- Fires .OnWrite, prints "write a = 5"
Table.DoSomething() -- Fires .OnRead, prints "executed", "read DoSomething"
print(Table.a) -- Fires .OnRead, prints 10, "read a"
task.wait(1)
NewHook:RawSet("a", 10) -- Doesnt call .OnWrite
print(NewHook:RawGet("a")) -- Doesnt call .OnRead, prints 10
```

### Creating a reactive variable:
```lua
local HookValue = Hooker.HookValue(1)
HookValue.OnChange:Connect(function(new, old)
	print("changed")
end)

HookValue:Set(10) -- Fires .OnChange
print(HookValue:Get()) -- 10

HookValue:ToggleFreeze(true) -- You can no longer change it's value.

HookValue:Set(100) -- warn
print(HookValue:Get()) -- 10
```

### Using hook functions with reactive tables:
```lua
local Table = {
	DoSomething = function()
		print("executed")
	end,
}

local NewHook, Table = Hooker.HookTable(Table)
NewHook.ReadFunction = function(self, Key)
	print("read ".. Key)
	return self[Key]
end

local HookFunction = Hooker.HookFunction(Table.DoSomething, NewHook:GetValues())
HookFunction.OnCall:Connect(function()
	print("function called")
end)
HookFunction:Replace(function(...)
	print("replacement called")
	return HookFunction.OriginalFunction(...)
end)

Table.DoSomething() --[[
	Prints a sequence: 
	 "read DoSomething", "read DoSomething", "replacement called", "executed", "function called"
]]
```
