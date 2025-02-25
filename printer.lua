local component = require("component")
local event = require("event")
local os = require("os")
local term = require("term")
local gpu = component.gpu
local math = require("math")

-- Получаем доступ к компоненту openprinter
local op = component.openprinter
if not op then
  error("Ошибка: Компонент openprinter не найден!")
end

-- Определяем разрешение экрана
local screenWidth, screenHeight = gpu.getResolution()

-- Конфигурация кнопки "Печатать билет" (главное меню)
local printButton = {
  x = math.floor(screenWidth / 2) - 15,
  y = math.floor(screenHeight / 2) - 2,
  w = 30,
  h = 5,
  color = 0x00AAFF,
  text = "Печатать билет"
}

-- Конфигурация кнопки "OK" (на экране результата)
local okButton = {
  x = math.floor(screenWidth / 2) - 10,
  y = math.floor(screenHeight / 2) + 2,
  w = 20,
  h = 3,
  color = 0x55FF55,
  text = "OK"
}

-- Функция очистки экрана
local function clearScreen()
  gpu.setBackground(0x1E1E1E)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")
end

-- Отрисовка кнопки "Печатать билет"
local function drawPrintButton()
  clearScreen()
  gpu.setBackground(printButton.color)
  gpu.fill(printButton.x, printButton.y, printButton.w, printButton.h, " ")
  gpu.setForeground(0x000000)
  local text = printButton.text
  local textX = printButton.x + math.floor((printButton.w - #text) / 2)
  local textY = printButton.y + math.floor(printButton.h / 2)
  gpu.set(textX, textY, text)
end

-- Отрисовка сообщения "Печатается..."
local function drawPrintingMessage()
  clearScreen()
  local msg = "Печатается..."
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x1E1E1E)
  local x = math.floor((screenWidth - #msg) / 2) + 1
  local y = math.floor(screenHeight / 2)
  gpu.set(x, y, msg)
end

-- Отрисовка экрана с сообщением о результате и кнопкой "OK"
local function drawDoneMessage(success)
  clearScreen()
  local msg = success and "Напечатано!" or "Ошибка печати!"
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x1E1E1E)
  local x = math.floor((screenWidth - #msg) / 2) + 1
  local y = math.floor(screenHeight / 2) - 1
  gpu.set(x, y, msg)
  
  -- Отрисовка кнопки "OK"
  gpu.setBackground(okButton.color)
  gpu.fill(okButton.x, okButton.y, okButton.w, okButton.h, " ")
  gpu.setForeground(0x000000)
  local text = okButton.text
  local textX = okButton.x + math.floor((okButton.w - #text) / 2)
  local textY = okButton.y + math.floor(okButton.h / 2)
  gpu.set(textX, textY, text)
end

-- Функция печати билета через API openprinter; возвращает true при успехе
local function printTicket(name)
    op.clear()
    op.setTitle("Налоговый билет")
    op.writeln("===== НАЛОГОВЫЙ БИЛЕТ =====", 0x000000, "center")
    op.writeln("Номер билета: " .. math.floor(math.random(1000, 9999)), 0x133007, "center")
    op.writeln("Дата: " .. os.date("%d.%m.%Y"), 0x000000, "center")
    op.writeln("Сумма: " .. math.floor(math.random(50, 100)) .. " монет.", 0x000000, "center")
    op.writeln("Платильник: " .. name, 0x000000, "center")
    op.writeln("Оплатите вовремя!", 0x630309, "center")
    op.writeln("(В течении 7 майнкрафт дней)", 0x000000, "center")
    op.writeln("===== СОВЕТ =====", 0x000000, "center")
    op.writeln("Приходите в налоговую", 0x307300, "center")
    op.writeln("раз в Неделю (Майнкрафтовски)", 0x307300, "center")
    op.writeln("чтобы избежать штрафов", 0x307300, "center")
    op.writeln("===== НЕ ЗАБУДЬТЕ =====", 0x000000, "center")
    op.writeln("Билет = 1 шанс пёрнуть", 0xFF5733, "center")
    op.writeln("- Миша", 0xFF5733, "center")
    op.writeln("===== ШУТКА =====", 0x000000, "center")
    
    -- Секретное сообщение (для шутки)
    local secretMessages = {
      "Помните, налоговая не шутит... или она шутит.",
      "Налоговая: приходите пораньше, чтобы успеть на обед!",
      "Налоги - это всё равно что ставить блоки: с каждым разом всё сложнее."
    }
    local randomMessage = secretMessages[math.random(#secretMessages)]
    op.writeln(randomMessage, 0xFFD700, "center")
    
    op.writeln("ЗАПЛАТИ ЕСЛИ НЕ ЛОХ", 0x000000, "center")
    -- Добавим веселую строку
    op.writeln("P.S. С налогами не шутят!", 0xFF00FF, "center")
    op.writeln("Но мы можем.", 0xFF00FF, "center")


  
    -- Печатаем билет
    local result = op.print()
    return result
  end
  
-- Состояния интерфейса: "menu", "printing", "done"
local state = "menu"
local doneTimestamp = 0

-- Изначально отображаем главное меню с кнопкой "Печатать билет"
drawPrintButton()

-- Глобальная переменная для хранения игрока
local currentPlayer = nil

while true do
  if state == "menu" then
    local eventData = { event.pull("touch") }
    if eventData[1] == "touch" then
      local _, _, x, y, button, player = table.unpack(eventData)
      currentPlayer = player  -- Сохраняем текущего игрока
      if x >= printButton.x and x < printButton.x + printButton.w and
         y >= printButton.y and y < printButton.y + printButton.h then
        state = "printing"
        drawPrintingMessage()
      end
    end

  elseif state == "printing" then
    -- Используем currentPlayer, который был сохранен ранее
    local result = printTicket(currentPlayer)
    state = "done"
    drawDoneMessage(result)
    doneTimestamp = os.time()  -- Запоминаем время перехода в состояние "done"

  elseif state == "done" then
    -- Ждём событие "touch" с таймаутом 0.5 сек
    local eventData = { event.pull(0.5, "touch") }
    if eventData[1] == "touch" then
      local _, _, x, y = table.unpack(eventData)
      if x >= okButton.x and x < okButton.x + okButton.w and
         y >= okButton.y and y < okButton.y + okButton.h then
        state = "menu"
        drawPrintButton()
      end
    else
      -- Если 8 секунд прошли, возвращаемся в главное меню
      if os.time() - doneTimestamp >= 150 then
        state = "menu"
        drawPrintButton()
      end
    end
  end
end
