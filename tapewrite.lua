local component = require("component")
local fs = require("filesystem")
local computer = require("computer")

-- Получаем адрес первого найденного лентопривода
local tapeAddress = nil
for address, proxy in component.list("tape") do
  tapeAddress = address
  print("Найден лентопривод по адресу: " .. address)
  break
end

if not tapeAddress then
  print("Лентопривод не найден!")
  return
end

local tape = component.proxy(tapeAddress)

if not tape.isReady() then
  print("Лента не вставлена или не готова!")
  return
end

-- Если лента воспроизводится, останавливаем её
if tape.getState() ~= "STOPPED" then
  tape.stop()
  computer.pullSignal(1)  -- небольшая задержка
end

-- Перематываем ленту в начало
local tapeSize = tape.getSize()
if tapeSize and tapeSize > 0 then
  local rewound = tape.seek(-tapeSize)
  print("Перемотка ленты: перемещено назад на " .. rewound .. " байт.")
else
  print("Не удалось получить размер ленты или размер равен 0.")
end

-- Путь к файлу
local filePath = "/home/d.dfpwm"
if not fs.exists(filePath) then
  print("Файл " .. filePath .. " не существует!")
  return
end

local fileHandle = io.open(filePath, "rb")
if not fileHandle then
  print("Не удалось открыть файл " .. filePath)
  return
end

-- Считываем весь файл как бинарную строку
local fileContent = fileHandle:read("*a")
fileHandle:close()

if not fileContent then
  print("Файл пуст или не удалось прочитать содержимое.")
  return
end

local totalBytes = #fileContent
local totalWritten = 0
local chunkSize = 512  -- Увеличен размер чанка для ускорения 

-- Печатаем все байты для проверки
print("Чтение байтов из файла и запись на ленту:")
for i = 1, totalBytes, chunkSize do
  local chunk = fileContent:sub(i, i + chunkSize - 1)
  
  -- Запись чанка байтов как строки
  local byteData = chunk
  tape.write(byteData)  -- Запись целиком чанка

  totalWritten = totalWritten + #chunk

  -- Можно добавить периодическую задержку для стабильности
  if totalWritten % 1000 == 0 then
    computer.pullSignal(0.01)  -- Уменьшена задержка
    print("Записано байт: " .. totalWritten)
  end
end

print("Запись завершена, записано байт: " .. totalWritten)
