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
Table.DoSomething() -- Prints "executed", then "Hello world!"
```

### Creating a hook function:
```lua
local HookTwo = Hooker.HookFunction(Table.DoSomething)
HookTwo:Replace(function(...)
	print("Hello world 2!")
	return HookTwo.OriginalFunction(...)
end)
HookTwo.Call() -- Prints "Hello world 2!", then "executed"
```

### Making a reactive table:
```lua
local NewHook, Table = Hooker.HookTable(Table)
NewHook.OnRead:Connect(function(Key)
	print("read ".. Key)
end)
NewHook.OnWrite:Connect(function(Key, Value)
	print("write ".. Key.. " = ".. Value)
end)

Table.a = 5 -- Fires .OnWrite
Table.DoSomething() -- Fires .OnRead
print(Table.a) -- Fires .OnRead
task.wait(1)
NewHook:RawSet("a", 10) -- Doesnt call .OnWrite
print(NewHook:RawGet("a")) -- Doesnt call .OnRead
```

### Creating a reactive variable:
```lua
local HookValue = Hooker.HookValue(1)
HookValue.OnChange:Connect(function(new, old)
	print("changed")
end)

HookValue:Set(10)
print(HookValue:Get()) -- 10

HookValue:ToggleFreeze(true) -- You can no longer change it's value.

HookValue:Set(100) -- warn
print(HookValue:Get()) -- 10
```
