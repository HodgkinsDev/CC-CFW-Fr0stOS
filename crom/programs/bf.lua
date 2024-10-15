local cell = {}
local cellptr = 1
local cell_limit = 10
local output = ""
local loaded = false
local function bl()
	print("")
end
local function cls()
	shell.run("clear")
end
function read_file(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return content
    end
end
function reset_interpreter(array, size)
    for i = 1, size do
        array[i] = 0
    end
	output = ""
	cellptr = 1
	cell_limit = 10
end
local function readChar()
    local line = io.read("*l")  
    return string.sub(line, 1, 1)  
end
local function visualizer(Cell_Count)
	if term.isColour() then
		term.setTextColour(colours.green)
	end
	local temp_count = 0
	for i = 1,Cell_Count do
		if temp_count == 10 then
			bl()
			temp_count = 0
		end
		if cell[i] == nil then
			cell[i] = 0
		end
		if i == cellptr then
			io.write("{",cell[i],"}")
		else
			io.write("[",cell[i],"]")
		end
		temp_count = temp_count + 1
	end
	term.setTextColour(colours.white)
end
local function ttl()
	if term.isColour() then
		term.setTextColour(colours.yellow)
	end
	print("Brainfuck Interpreter 0.1")
	bl()
	print("Type Q or q to exit.")
	print("Type L or l to load a .bf file")
	print("Type R or r to reset interpreter")
	bl()
	term.setTextColour(colours.white)
	visualizer(cell_limit)
	bl()
	bl()
	print("Output:")
	print(output)
end
local function bf_execute(exe_cmd)
    local A = 1
    local length = string.len(exe_cmd)
    while A <= length do
        local cmd = string.sub(exe_cmd, A, A)
        if cmd == ">" then 
            cellptr = cellptr + 1
            if cellptr > cell_limit then
                cell_limit = cell_limit + 1
                cell[cell_limit] = 0 
            end
        elseif cmd == "<" then
            cellptr = cellptr - 1
            if cellptr < 1 then
                cellptr = 1
            end
        elseif cmd == "+" then
            cell[cellptr] = (cell[cellptr] or 0) + 1
            if cell[cellptr] == 256 then 
                cell[cellptr] = 0
            end
        elseif cmd == "-" then
            cell[cellptr] = (cell[cellptr] or 0) - 1
            if cell[cellptr] == -1 then 
                cell[cellptr] = 255
            end
        elseif cmd == "." then
            output = output .. string.char(cell[cellptr] or 0)
        elseif cmd == "," then
			cls()
			if loaded == false then
				ttl()
			else
				io.write(output)
			end
            local input = readChar()
            cell[cellptr] = string.byte(input)
        elseif cmd == "[" then
            if cell[cellptr] == 0 then
                local balance = 1
                while balance > 0 do
                    A = A + 1
                    local current_char = string.sub(exe_cmd, A, A)
                    if current_char == "[" then
                        balance = balance + 1
                    elseif current_char == "]" then
                        balance = balance - 1
                    end
                end
            end
        elseif cmd == "]" then
            if cell[cellptr] ~= 0 then
                local balance = -1
                while balance < 0 do
                    A = A - 1
                    local current_char = string.sub(exe_cmd, A, A)
                    if current_char == "[" then
                        balance = balance + 1
                    elseif current_char == "]" then
                        balance = balance - 1
                    end
                end
            end
        end
        A = A + 1
    end
end
local args = {...}
local function main()
    if #args > 1 then
        print("Usage: bf <path>")
    elseif #args == 1 then
		local file_contents = read_file(arg[1])
		if file_contents ~= nil then
			loaded = true
			bf_execute(file_contents)
		end
    else
		while true do
			cls()
			ttl()
			io.write("bf>:")
			local bfcmd = io.read()
			if bfcmd == "Q" or bfcmd == "q" then
				break
			elseif bfcmd == "R" or bfcmd == "r" then
				reset_interpreter(cell,cell_limit)
			elseif bfcmd == nil then
			elseif bfcmd == "L" or bfcmd == "l" then
				bl()
				io.write("Path to .bf File:")
				local path = io.read()
				local file_contents = read_file(path)
				if file_contents ~= nil then
					bf_execute(file_contents)
				end
			else
				bf_execute(bfcmd)
			end
		end
	end
end
main()