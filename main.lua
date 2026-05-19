-- Obiekt kamery (ruch po skosie z blokadą granic)
local camera = {
    x = 0,
    y = 0,
    scale = 2, 
    speed = 400
}

local grassImage
local borderImage
local tileMap = {}
local MAP_SIZE = 32 -- Świat jest sztywno zablokowany na 32x32

local tileW = 36
local tileH = 18 

function tileToIso(tileX, tileY)
    local isoX = (tileX - tileY) * (tileW / 2)
    local isoY = (tileX + tileY) * (tileH / 2)
    return isoX, isoY
end

function isoToTile(screenX, screenY)
    local worldX = (screenX / camera.scale) + camera.x
    local worldY = (screenY / camera.scale) + camera.y

    local tileX = (worldX / (tileW / 2) + worldY / (tileH / 2)) / 2
    local tileY = (worldY / (tileH / 2) - worldX / (tileW / 2)) / 2

    return math.floor(tileX), math.floor(tileY)
end

function love.load()
    love.window.setMode(1000, 750)
    love.window.setTitle("Izometryczna Wyspa 32x32 z Ciemnym Borderem w Rogach")

    grassImage = love.graphics.newImage("assets/tiles/grass.png")
    borderImage = love.graphics.newImage("assets/tiles/border.png")
    pathImage = love.graphics.newImage("assets/tiles/path.png")
    -- GENEROWANIE MAPY 32x32
    for x = 0, MAP_SIZE - 1 do
        tileMap[x] = {}
        for y = 0, MAP_SIZE - 1 do
            if x == 0 or x == MAP_SIZE - 1 or y == 0 or y == MAP_SIZE - 1 then
                tileMap[x][y] = "border"
            else
                tileMap[x][y] = "grass"
            end
        end
    end

    -- Ustawienie kamery na środku wyspy na starcie
    local midX, midY = tileToIso(MAP_SIZE / 2, MAP_SIZE / 2)
    camera.x = midX - (love.graphics.getWidth() / 2 / camera.scale)
    camera.y = midY - (love.graphics.getHeight() / 2 / camera.scale)
end

function love.update(dt)
    -- 1. Zapamiętujemy pozycję przed ruchem, aby móc ją cofnąć na krawędzi mapy
    local oldX = camera.x
    local oldY = camera.y

    -- 2. Ruch kamery po skosie (WSAD)
    local dx = 0
    local dy = 0

    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then dx = dx + 1 end
    if love.keyboard.isDown("left") or love.keyboard.isDown("a")  then dx = dx - 1 end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s")  then dy = dy + 1 end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w")    then dy = dy - 1 end

    if dx ~= 0 or dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length

        local isoDX = (dx - dy) * (tileW / 2)
        local isoDY = (dx + dy) * (tileH / 2)

        camera.x = camera.x + isoDX * (camera.speed / 20) * dt
        camera.y = camera.y + isoDY * (camera.speed / 20) * dt
    end

    -- 3. SZTYWNA BLOKADA KAMERY NA MAPIE 32x32
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2
    local centerTileX, centerTileY = isoToTile(centerX, centerY)

    -- Jeśli środek ekranu próbuje opuścić mapę 32x32, cofamy ruch kamery
    if centerTileX < 0 or centerTileX >= MAP_SIZE or centerTileY < 0 or centerTileY >= MAP_SIZE then
        camera.x = oldX
        camera.y = oldY
    end

    -- 4. Interakcja myszką (Rysowanie tylko w granicach głównej mapy)
    local mouseX, mouseY = love.mouse.getPosition()
    local tileX, tileY = isoToTile(mouseX, mouseY)

    if love.mouse.isDown(1) then
        if tileX >= 0 and tileX < MAP_SIZE and tileY >= 0 and tileY < MAP_SIZE then
            tileMap[tileX][tileY] = "path"
        end
    end
end

function love.draw()
    love.graphics.push()
    
    love.graphics.scale(camera.scale)
    love.graphics.translate(-camera.x, -camera.y)

    drawWorld()

    love.graphics.pop()

    drawUI()
end

function drawWorld()
    local mouseX, mouseY = love.mouse.getPosition()
    local hoverX, hoverY = isoToTile(mouseX, mouseY)

    -- 1. WARSTWA ZEWNĘTRZNA (TŁO) - Rysujemy najpierw, bo i tak wszystko ma być pod spodem
    local padding = 12
    for x = -padding, MAP_SIZE - 1 + padding do
        for y = -padding, MAP_SIZE - 1 + padding do
            local isInsideMap = (x >= 0 and x < MAP_SIZE and y >= 0 and y < MAP_SIZE)
            if not isInsideMap then
                local isoX, isoY = tileToIso(x, y)
                if x == hoverX and y == hoverY then
                    love.graphics.setColor(0.2, 0.2, 0.2)
                else
                    love.graphics.setColor(0.35, 0.35, 0.4)
                end
                love.graphics.draw(borderImage, isoX, isoY)
            end
        end
    end

    -- 2. WARSTWA GŁÓWNA (WYSPA 32x32) - POPRAWNE SORTOWANIE (OD TYŁU DO PRZODU)
    -- Maksymalna suma indeksów dla mapy 32x32 to (31 + 31) = 62
    for d = 0, (MAP_SIZE - 1) * 2 do
        for x = 0, d do
            local y = d - x
            -- Sprawdzamy, czy wyliczone x i y mieszczą się w granicach mapy
            if x >= 0 and x < MAP_SIZE and y >= 0 and y < MAP_SIZE then
                local isoX, isoY = tileToIso(x, y)

                -- Ustawienie koloru i hover
                if x == hoverX and y == hoverY then
                    love.graphics.setColor(0.7, 0.7, 0.7)
                else
                    love.graphics.setColor(1, 1, 1)
                end

                -- Renderowanie we właściwej kolejności
                if tileMap[x][y] == "grass" then
                    love.graphics.draw(grassImage, isoX, isoY)
                elseif tileMap[x][y] == "border" then
                    love.graphics.draw(borderImage, isoX, isoY)
                elseif tileMap[x][y] == "path" then
                -- Obliczamy skalę: docelowa szerokość (tileW) podzielona przez faktyczną szerokość obrazka (128)
                local scaleX = tileW / pathImage:getWidth()
                local scaleY = tileH / pathImage:getHeight()
    
                -- Rysujemy z odpowiednim skalowaniem X i Y
                    love.graphics.draw(pathImage, isoX, isoY, 0, scaleX, scaleY)
                    end
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1) -- Reset koloru na koniec
end


function drawUI()
    love.graphics.setColor(1, 1, 1)
    local mouseX, mouseY = love.mouse.getPosition()
    local tileX, tileY = isoToTile(mouseX, mouseY)
    
    local centerX, centerY = isoToTile(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    
    love.graphics.print("Myszka nad kafelkiem: X: " .. tileX .. " Y: " .. tileY, 10, 10)
    love.graphics.print("Środek ekranu na kafelku: X: " .. centerX .. " Y: " .. centerY, 10, 30)
    love.graphics.print("ROZMIAR ŚWIATA ZABLOKOWANY NA 32x32. Czarnych rogów brak (zakryte ciemnym borderem).", 10, 50)
end