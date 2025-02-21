local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")
local term = require("term")
local event = require("event")
local gpu = component.gpu

-- Настройки экрана
local screenWidth, screenHeight = gpu.getResolution()
local centerX = math.floor(screenWidth / 2)
local centerY = math.floor(screenHeight / 2)

local function restoreProfileFile()
    print("\nВосстановление файла /etc/profile.lua...")
    local originalProfile = [[
local shell = require("shell")
local tty = require("tty")
local fs = require("filesystem")

if tty.isAvailable() then
  if io.stdout.tty then
    io.write("\27[40m\27[37m")
    tty.clear()
  end
end
dofile("/etc/motd")

shell.setAlias("dir", "ls")
shell.setAlias("move", "mv")
shell.setAlias("rename", "mv")
shell.setAlias("copy", "cp")
shell.setAlias("del", "rm")
shell.setAlias("md", "mkdir")
shell.setAlias("cls", "clear")
shell.setAlias("rs", "redstone")
shell.setAlias("view", "edit -r")
shell.setAlias("help", "man")
shell.setAlias("l", "ls -lhp")
shell.setAlias("..", "cd ..")
shell.setAlias("df", "df -h")
shell.setAlias("grep", "grep --color")
shell.setAlias("more", "less --noback")
shell.setAlias("reset", "resolution `cat /dev/components/by-type/gpu/0/maxResolution`")

os.setenv("EDITOR", "/bin/edit")
os.setenv("HISTSIZE", "10")
os.setenv("HOME", "/home")
os.setenv("IFS", " ")
os.setenv("MANPATH", "/usr/man:.")
os.setenv("PAGER", "less")
os.setenv("PS1", "\27[40m\27[31m$HOSTNAME$HOSTNAME_SEPARATOR$PWD # \27[37m")
os.setenv("LS_COLORS", "di=0;36:fi=0:ln=0;33:*.lua=0;32")

shell.setWorkingDirectory(os.getenv("HOME"))

local home_shrc = shell.resolve(".shrc")
if fs.exists(home_shrc) then
  loadfile(shell.resolve("source", "lua"))(home_shrc)
end
    ]]
    
    local file = io.open("/etc/profile.lua", "w")
    file:write(originalProfile)
    file:close()
    print("\n✅ Файл /etc/profile.lua восстановлен.")
end

-- Звук запуска
local function playStartupSound()
    term.clear()
    term.setCursor(centerX - 7, centerY)
    term.write("Антивирус загружается...")
    computer.beep(440, 0.2)  -- Нота A4
    computer.beep(523, 0.2)  -- Нота C5
    computer.beep(659, 0.2)  -- Нота E5
end

-- Отображение загрузки с процентами
local function showLoadingScreen()
    term.clear()
    term.setCursor(0, 0)
    term.write("V 1.2")
    term.setCursor(centerX - 7, centerY)
    term.write("Антивирус загружается...\n")
    term.write("KopeikaSoft")
    
    for i = 1, 100, math.random(5, 15) do
        os.sleep(0.1)
        term.setCursor(centerX - 2, centerY + 2)
        term.write(i .. "% ")
    end

    term.setCursor(centerX - 2, centerY + 2)
    term.write("100% Готово!")
    os.sleep(0.5)
end

-- База данных подозрительных кодов и имен
local suspiciousNames = {
    "virus", "virus.lua", "mischief", "malware", "trojan", "backdoor", "ransomware",
    "exploit", "hack", "worm", "rootkit", "keylogger", "botnet", "zombie", "spyware",
    "phishing", "adware", "scareware", "spy", "tracker", "flooder", "sniffer", "crypter", 
    "exfiltrate", "payload", "brute_force", "darknet", "bypass", "recon", "inject", "shellcode",
    "persistence", "backdoor.lua", "payload.lua", "trojan.lua"
}

local suspiciousCodeSnippets = {
    "local fs = require(\"filesystem\")",
    "shell.execute",
    "os.execute",
    "computer.beep",
    "lua ", -- Команда для запуска файла
    "require(\"os\")",
    "require(\"computer\")",
    "computer.shutdown",
    "computer.reboot",
    "os.getenv",
    "fs.open",
    "fs.remove",
    "fs.rename",
    "file.write",
    "file.read",
    "io.popen",
    "io.output",
    "io.input",
    "os.execute",
    "process.waitForExit",
    "network.request",
    "downloadfile",
    "wget",
    "curl",
    "fetch",
    "pastebin",
    "infection",
    "mischief",
    "virus",
    "payload"
}


-- Сканирование файлов и папок
local function scanFolders()
    term.clear()
    term.setCursor(2, 2)
    print("🔍 Сканирование папки /home и /etc/profile.lua...")
    print("❌Напоминание❌:\n Часто антивирус детектид обычные прогграмы, будте осторожны при удалении!")

    local filesScanned = 0
    local suspiciousFound = false
    local foundFiles = {}

    -- Функция для сканирования и проверки файлов
    local function checkFile(filePath)
        local file = io.open(filePath, "r")
        if not file then return end

        local content = file:read("*a")
        file:close()

        -- Проверка на совпадение с базой данных подозрительных имен
        for _, name in ipairs(suspiciousNames) do
            if filePath:find(name) then
                print("⚠️ Найдено подозрительное имя файла: " .. filePath)
                table.insert(foundFiles, filePath)
                suspiciousFound = true
            end
        end

        -- Проверка на совпадение с базой данных кодов
        for _, snippet in ipairs(suspiciousCodeSnippets) do
            if content:find(snippet) then
                print("⚠️ Найдено подозрительное содержимое в: " .. filePath)
                table.insert(foundFiles, filePath)
                suspiciousFound = true
            end
        end
    end

    -- Сканируем каталог /home
    local function scanHomeDirectory()
        for file in filesystem.list("/home") do
            local fullPath = "/home/" .. file
            if filesystem.isDirectory(fullPath) then
                scanHomeDirectory(fullPath)
            else
                filesScanned = filesScanned + 1
                local progress = math.floor((filesScanned / 100) * 100)  -- Для простоты, показываем 100 файлов
                term.setCursor(centerX - 10, centerY + 3)
                term.write("Сканирование: " .. progress .. "%")
                checkFile(fullPath)
                os.sleep(0.05)  -- Задержка между файлами
            end
        end
    end

    -- Сканируем файл /etc/profile.lua
    local function scanProfileFile()
        checkFile("/etc/profile.lua")
    end

    -- Сканируем папку и файл
    scanHomeDirectory()
    scanProfileFile()

    if not suspiciousFound then
        term.clear()
        term.setCursor(0, 0)
        print("\n✅ Все файлы проверены. Опасных данных не найдено.")
    else
        term.clear()
        term.setCursor(0, 0)
        print("\n⚠️ Сканирование завершено с предупреждениями!")
        print("Найденные подозрительные файлы/код:")

        -- Выводим все найденные подозрительные файлы
        for _, file in ipairs(foundFiles) do
            print(file)
        end
        print("Хотите удалить все подозрительные файлы? (y/n) \n(При выборе n вы сможете выбрать отдельные файлы)")
        local response = io.read()
        if response:lower() == "y" then
            for _, file in ipairs(foundFiles) do
                if filesystem.exists(file) then
                    filesystem.remove(file)
                    print("Удален файл: " .. file)
                end
            end
            print("Все найденные файлы удалены.")
        else
            -- Если нет, спрашиваем для каждого файла по очереди
            for _, file in ipairs(foundFiles) do
                print("Удалить файл: " .. file .. "? (y/n)")
                local deleteResponse = io.read()

                if deleteResponse:lower() == "y" then
                    if filesystem.exists(file) then
                        filesystem.remove(file)
                        print("Удален файл: " .. file)
                    end
                elseif deleteResponse:lower() == "n" then
                    print("Файл не удален: " .. file)
                else
                    print("Неверный ввод, файл не удален.")
                end
            end
        end
    end
end


-- Главное меню
local function showMainMenu()
    while true do
        term.clear()
        term.setCursor(centerX - 5, centerY - 2)
        print("🛡 OpenOS Антивирус")
        term.setCursor(centerX - 8, centerY)
        print("[1] Сканировать систему")
        term.setCursor(centerX - 8, centerY + 1)
        print("[2] Выход")
        term.setCursor(centerX - 8, centerY + 3)
        io.write("Выбор: ")
        local choice = io.read()

        if choice == "1" then
            scanFolders()
            restoreProfileFile()
            print("\nНажмите любую клавишу для возврата...")
            event.pull("key")
        elseif choice == "2" then
            restoreProfileFile()
            term.clear()
            print("🔒 Антивирус завершил работу.")
            os.exit()
        end
    end
end

-- Запуск антивируса
playStartupSound()
showLoadingScreen()
showMainMenu()
