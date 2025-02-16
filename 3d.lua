local component = require("component")
local gpu = component.gpu
local event = require("event")
local os = require("os")

-- Получаем текущие размеры экрана
local screenWidth, screenHeight = gpu.getResolution()

-- Определяем вершины куба (координаты от -1 до 1)
local cubeVertices = {
  {-1, -1, -1},
  { 1, -1, -1},
  { 1,  1, -1},
  {-1,  1, -1},
  {-1, -1,  1},
  { 1, -1,  1},
  { 1,  1,  1},
  {-1,  1,  1}
}

-- Определяем рёбра куба (номера вершин, учитывая, что таблицы Lua индексируются с 1)
local cubeEdges = {
  {1,2}, {2,3}, {3,4}, {4,1},
  {5,6}, {6,7}, {7,8}, {8,5},
  {1,5}, {2,6}, {3,7}, {4,8}
}

-- Функция поворота точки p вокруг осей X, Y и Z
local function rotatePoint(p, angleX, angleY, angleZ)
  local x, y, z = p[1], p[2], p[3]
  -- Поворот вокруг X
  local cosX, sinX = math.cos(angleX), math.sin(angleX)
  local y1 = y * cosX - z * sinX
  local z1 = y * sinX + z * cosX
  y, z = y1, z1

  -- Поворот вокруг Y
  local cosY, sinY = math.cos(angleY), math.sin(angleY)
  local x1 = x * cosY + z * sinY
  local z2 = -x * sinY + z * cosY
  x, z = x1, z2

  -- Поворот вокруг Z
  local cosZ, sinZ = math.cos(angleZ), math.sin(angleZ)
  local x2 = x * cosZ - y * sinZ
  local y2 = x * sinZ + y * cosZ
  return {x2, y2, z}
end

-- Функция перспективной проекции точки (простейшая модель)
local function projectPoint(p, distance)
  local x, y, z = p[1], p[2], p[3]
  local factor = distance / (distance + z)
  return {x * factor, y * factor}
end

-- Функция отрисовки линии с помощью алгоритма Брезенхэма
local function drawLine(x0, y0, x1, y1, char)
  char = char or "#"
  local dx = math.abs(x1 - x0)
  local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy

  while true do
    if x0 >= 1 and x0 <= screenWidth and y0 >= 1 and y0 <= screenHeight then
      gpu.set(x0, y0, char)
    end
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then
      err = err - dy
      x0 = x0 + sx
    end
    if e2 < dx then
      err = err + dx
      y0 = y0 + sy
    end
  end
end

-- Основные параметры анимации
local angle = 0
local angleSpeed = 0.05   -- скорость поворота (в радианах за кадр)
local distance = 4        -- расстояние для перспективной проекции
local scale = math.min(screenWidth, screenHeight) / 4

-- Главный цикл анимации
while true do
  -- Очищаем экран (заполняем пробелами)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")

  local projected = {}
  -- Обрабатываем каждую вершину: поворот и проекция на 2D
  for i, vertex in ipairs(cubeVertices) do
    local rotated = rotatePoint(vertex, angle, angle, angle)
    local proj = projectPoint(rotated, distance)
    -- Масштабируем и смещаем в центр экрана
    local x = math.floor(screenWidth/2 + proj[1] * scale)
    local y = math.floor(screenHeight/2 - proj[2] * scale)
    projected[i] = {x, y}
  end

  -- Рисуем рёбра куба
  for _, edge in ipairs(cubeEdges) do
    local p1 = projected[edge[1]]
    local p2 = projected[edge[2]]
    drawLine(p1[1], p1[2], p2[1], p2[2])
  end

  -- Увеличиваем угол поворота для следующего кадра
  angle = angle + angleSpeed

  -- Небольшая задержка между кадрами
  os.sleep(0.05)
  
  -- Если нажата любая клавиша, выходим из цикла (опционально)
  if event.pull(0, "key_down") then break end
end
