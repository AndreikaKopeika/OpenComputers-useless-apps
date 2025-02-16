--[[ 
    Финальный оптимизированный 3D-движок для OpenComputers:
     • Отрисовка пикселей символом "█" с затемнением базового цвета в зависимости от глубины.
     • Большая платформа (пол) с фоном, заполненным светло-голубым цветом (0x87CEEB).
     • Камера (игрок) расположена чуть ниже.
     • Пирамида (с квадратным основанием) стоит на платформе.
     • Поворот камеры: клавиша ← увеличивает угол, → уменьшает (инвертировано).
    
    Управление:
      W/S — движение вперёд/назад
      A/D — движение в стороны
      Стрелки — поворот камеры (←/→) и наклон (↑/↓)
      Q   — выход из программы
--]]

local component = require("component")
local gpu = component.gpu
local keyboard = require("keyboard")
local os = require("os")
local math = require("math")

-- Получаем разрешение экрана
local width, height = gpu.getResolution()

-- Задаём цвет фона (голубой)
local BG_COLOR = 0x87CEEB

-- Буферы экрана и Z-буфер
local screenBuffer = {}
local zBuffer = {}

local function initBuffers()
  for y = 1, height do
    screenBuffer[y] = {}
    zBuffer[y] = {}
    for x = 1, width do
      screenBuffer[y][x] = { char = " ", color = BG_COLOR }
      zBuffer[y][x] = math.huge
    end
  end
end

local function clearBuffers()
  for y = 1, height do
    for x = 1, width do
      screenBuffer[y][x].char = " "
      screenBuffer[y][x].color = BG_COLOR
      zBuffer[y][x] = math.huge
    end
  end
end

-- Вычисление яркости по глубине (чем дальше – темнее)
local function computeBrightness(depth)
  local maxDepth = 20
  local brightness = 1 - math.min(depth / maxDepth, 1)
  return brightness
end

-- Затемнение базового цвета по фактору яркости
local function darkenColor(color, factor)
  local r = math.floor(color / 0x10000) % 256
  local g = math.floor(color / 0x100) % 256
  local b = color % 256
  r = math.floor(r * factor)
  g = math.floor(g * factor)
  b = math.floor(b * factor)
  return r * 0x10000 + g * 0x100 + b
end

-- Всегда используем символ "█" для пикселей
local function getPixelChar()
  return "█"
end

-- Запись пикселя в буфер с проверкой Z-буфера
local function putPixel(x, y, depth, baseColor)
  x = math.floor(x)
  y = math.floor(y)
  if x < 1 or x > width or y < 1 or y > height then return end
  if depth < zBuffer[y][x] then
    local brightness = computeBrightness(depth)
    local newColor = darkenColor(baseColor, brightness)
    zBuffer[y][x] = depth
    screenBuffer[y][x].char = getPixelChar()
    screenBuffer[y][x].color = newColor
  end
end

-- Группированный вывод буфера для уменьшения числа вызовов GPU
local function flushBuffer()
  for y = 1, height do
    local row = screenBuffer[y]
    local segs = {}
    local currentColor = row[1].color
    local currentStart = 1
    local currentChars = {}
    for x = 1, width do
      local cell = row[x]
      if cell.color == currentColor then
        currentChars[#currentChars + 1] = cell.char
      else
        segs[#segs + 1] = {start = currentStart, str = table.concat(currentChars), color = currentColor}
        currentColor = cell.color
        currentStart = x
        currentChars = { cell.char }
      end
    end
    segs[#segs + 1] = {start = currentStart, str = table.concat(currentChars), color = currentColor}
    for _, seg in ipairs(segs) do
      gpu.setForeground(seg.color)
      gpu.set(seg.start, y, seg.str)
    end
  end
end

-- Параметры камеры (игрока)
local camera = {
  x = 0,
  y = 1.2,    -- ниже, чем раньше
  z = -5,
  angle = 0,  -- yaw (горизонтальный поворот)
  pitch = 0   -- pitch (наклон)
}

-- Предвычисляемые значения для поворота по yaw
local camCos, camSin = 1, 0

-- Преобразование мировой точки в координаты камеры с учетом yaw и pitch
local function transformPoint(x, y, z)
  local dx = x - camera.x
  local dy = y - camera.y
  local dz = z - camera.z
  -- Поворот по yaw:
  local tx = dx * camCos - dz * camSin
  local tz = dx * camSin + dz * camCos
  -- Поворот по pitch (вокруг оси X):
  local cp = math.cos(camera.pitch)
  local sp = math.sin(camera.pitch)
  local ty = dy * cp - tz * sp
  local tz2 = dy * sp + tz * cp
  return tx, ty, tz2
end

-- Перспективная проекция (центр экрана и инверсия оси Y)
local function projectPoint(x, y, z)
  local fov = math.pi/3
  local scale = (width / 2) / math.tan(fov / 2)
  local px = (x * scale) / z + width / 2
  local py = height / 2 - (y * scale) / z
  return px, py
end

-- Получение вершин куба (8 точек)
local function getCubeVertices(cube)
  local s = cube.size / 2
  return {
    { x = cube.x - s, y = cube.y - s, z = cube.z - s },
    { x = cube.x + s, y = cube.y - s, z = cube.z - s },
    { x = cube.x + s, y = cube.y + s, z = cube.z - s },
    { x = cube.x - s, y = cube.y + s, z = cube.z - s },
    { x = cube.x - s, y = cube.y - s, z = cube.z + s },
    { x = cube.x + s, y = cube.y - s, z = cube.z + s },
    { x = cube.x + s, y = cube.y + s, z = cube.z + s },
    { x = cube.x - s, y = cube.y + s, z = cube.z + s }
  }
end

-- Рисование линии с интерполяцией координат и глубины
local function drawLineWithDepth(x1, y1, z1, x2, y2, z2, baseColor)
  local dx = x2 - x1
  local dy = y2 - y1
  local steps = math.max(math.abs(dx), math.abs(dy))
  if steps == 0 then
    putPixel(x1, y1, z1, baseColor)
    return
  end
  local invSteps = 1 / steps
  for i = 0, steps do
    local t = i * invSteps
    local x = x1 + dx * t
    local y = y1 + dy * t
    local z = z1 + (z2 - z1) * t
    putPixel(x, y, z, baseColor)
  end
end

-- Рисование куба (отрисовка рёбер)
local function drawCube(cube)
  local vertices = getCubeVertices(cube)
  local projected = {}
  for i, v in ipairs(vertices) do
    local tx, ty, tz = transformPoint(v.x, v.y, v.z)
    if tz <= 0 then
      projected[i] = nil
    else
      local px, py = projectPoint(tx, ty, tz)
      projected[i] = { x = px, y = py, z = tz }
    end
  end
  local edges = {
    {1,2}, {2,3}, {3,4}, {4,1},
    {5,6}, {6,7}, {7,8}, {8,5},
    {1,5}, {2,6}, {3,7}, {4,8}
  }
  for _, edge in ipairs(edges) do
    local p1 = projected[edge[1]]
    local p2 = projected[edge[2]]
    if p1 and p2 then
      drawLineWithDepth(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, cube.color)
    end
  end
end

-- Рисование увеличенной платформы (пол) с фоном
local function drawFloor()
  local gridSize = 1
  local floorY = 0
  -- Линии вдоль оси Z (для каждого X)
  for x = -20, 20, gridSize do
    local startWorld = { x = x, y = floorY, z = 0 }
    local endWorld   = { x = x, y = floorY, z = 40 }
    local tx1, ty1, tz1 = transformPoint(startWorld.x, startWorld.y, startWorld.z)
    local tx2, ty2, tz2 = transformPoint(endWorld.x, endWorld.y, endWorld.z)
    if tz1 > 0 and tz2 > 0 then
      local px1, py1 = projectPoint(tx1, ty1, tz1)
      local px2, py2 = projectPoint(tx2, ty2, tz2)
      drawLineWithDepth(px1, py1, tz1, px2, py2, tz2, 0xAAAAAA)
    end
  end
  -- Линии вдоль оси X (для каждого Z)
  for z = 0, 40, gridSize do
    local startWorld = { x = -20, y = floorY, z = z }
    local endWorld   = { x = 20, y = floorY, z = z }
    local tx1, ty1, tz1 = transformPoint(startWorld.x, startWorld.y, startWorld.z)
    local tx2, ty2, tz2 = transformPoint(endWorld.x, endWorld.y, endWorld.z)
    if tz1 > 0 and tz2 > 0 then
      local px1, py1 = projectPoint(tx1, ty1, tz1)
      local px2, py2 = projectPoint(tx2, ty2, tz2)
      drawLineWithDepth(px1, py1, tz1, px2, py2, tz2, 0xAAAAAA)
    end
  end
end

-- Рисование пирамиды (пирамида с квадратным основанием)
local function drawPyramid(pyr)
  local vertices = pyr.vertices
  local projected = {}
  for i, v in ipairs(vertices) do
    local tx, ty, tz = transformPoint(v.x, v.y, v.z)
    if tz <= 0 then
      projected[i] = nil
    else
      local px, py = projectPoint(tx, ty, tz)
      projected[i] = { x = px, y = py, z = tz }
    end
  end
  -- Рёбра: основание (квадрат) и от каждой вершины основания к верхушке (пятая точка)
  local edges = {
    {1,2}, {2,3}, {3,4}, {4,1},  -- основание
    {1,5}, {2,5}, {3,5}, {4,5}   -- боковые ребра
  }
  for _, edge in ipairs(edges) do
    local p1 = projected[edge[1]]
    local p2 = projected[edge[2]]
    if p1 and p2 then
      drawLineWithDepth(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, pyr.color)
    end
  end
end

-- Объекты в сцене
local cubes = {
  { x =  0,  y = 0.5, z =  5,  size = 1, color = 0xFF0000 },
  { x =  2,  y = 0.5, z = 10,  size = 1, color = 0x00FF00 },
  { x = -2,  y = 0.5, z = 15,  size = 1, color = 0x0000FF }
}

local pyramids = {
  { 
    vertices = {
      { x = -1, y = 0,  z = 12 },
      { x =  1, y = 0,  z = 12 },
      { x =  1, y = 0,  z = 14 },
      { x = -1, y = 0,  z = 14 },
      { x =  0, y = 3,  z = 13 }  -- верхушка
    },
    color = 0xFFFF00
  }
}

-- Инициализируем буферы
initBuffers()

-- Главный игровой цикл
local running = true
while running do
  clearBuffers()
  
  -- Предвычисляем углы для поворота по yaw
  camCos = math.cos(-camera.angle)
  camSin = math.sin(-camera.angle)
  
  -- Рисуем сцену
  drawFloor()
  for _, cube in ipairs(cubes) do
    drawCube(cube)
  end
  for _, pyr in ipairs(pyramids) do
    drawPyramid(pyr)
  end
  
  flushBuffer()
  
  -- Обработка ввода через Keyboard API
  if keyboard.isKeyDown(keyboard.keys.w) then
    camera.x = camera.x + math.sin(camera.angle) * 0.2
    camera.z = camera.z + math.cos(camera.angle) * 0.2
  end
  if keyboard.isKeyDown(keyboard.keys.s) then
    camera.x = camera.x - math.sin(camera.angle) * 0.2
    camera.z = camera.z - math.cos(camera.angle) * 0.2
  end
  if keyboard.isKeyDown(keyboard.keys.a) then
    camera.x = camera.x - math.cos(camera.angle) * 0.2
    camera.z = camera.z + math.sin(camera.angle) * 0.2
  end
  if keyboard.isKeyDown(keyboard.keys.d) then
    camera.x = camera.x + math.cos(camera.angle) * 0.2
    camera.z = camera.z - math.sin(camera.angle) * 0.2
  end
  -- Меняем местами стрелки: ← увеличивает, → уменьшает угол камеры
  if keyboard.isKeyDown(keyboard.keys.left) then
    camera.angle = camera.angle + 0.1
  end
  if keyboard.isKeyDown(keyboard.keys.right) then
    camera.angle = camera.angle - 0.1
  end
  if keyboard.isKeyDown(keyboard.keys.up) then
    camera.pitch = camera.pitch + 0.05
  end
  if keyboard.isKeyDown(keyboard.keys.down) then
    camera.pitch = camera.pitch - 0.05
  end
  if keyboard.isKeyDown(keyboard.keys.q) then
    running = false
  end
  
  os.sleep(0.01)
end

-- Очистка экрана при выходе
gpu.fill(1, 1, width, height, " ")
print("Выход из игры.")
