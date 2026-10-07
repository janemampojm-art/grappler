local equipped, busy, lastUse = false, false, -999999

local function notify(msg) TriggerEvent('esx:showNotification', msg) end
local function dbg(...) if Config.Debug then print('[grapple]', ...) end end

local function camDir()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

local function raycast()
    local from = GetGameplayCamCoord()
    local to = from + camDir() * Config.MaxDistance
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 511, PlayerPedId(), 4)
    local _, hit, coords, normal = GetShapeTestResult(h)
    return (hit == 1 or hit == true), coords, normal
end

local function help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function pull(coords, normal)
    busy = true
    lastUse = GetGameTimer()
    local ped = PlayerPedId()

    local target, wall
    if normal.z > 0.6 then
        target = coords + vector3(0.0, 0.0, 1.0)      -- gornja površina (krov, ivica)
    else
        wall = true
        target = coords + normal * 0.7 + vector3(0.0, 0.0, 0.3) -- zid
    end

    RequestAnimDict('skydive@base')
    local t = GetGameTimer() + 1000
    while not HasAnimDictLoaded('skydive@base') and GetGameTimer() < t do Wait(0) end
    SetPedCanRagdoll(ped, false)
    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, 'skydive@base', 'free_idle', 8.0, -8.0, -1, 1, 0.0, false, false, false)

    local t0 = GetGameTimer()
    while GetGameTimer() - t0 < Config.MaxPullTime do
        Wait(0)
        local p = GetEntityCoords(ped)
        local d = target - p
        local dist = #d
        if dist < 1.0 then break end
        local step = math.min(dist, Config.Speed * GetFrameTime())
        local np = p + (d / dist) * step
        SetEntityCoordsNoOffset(ped, np.x, np.y, np.z, false, false, false)
        SetEntityHeading(ped, GetHeadingFromVector_2d(d.x, d.y))
        local hand = GetPedBoneCoords(ped, 28422, 0.0, 0.0, 0.0)
        DrawLine(hand.x, hand.y, hand.z, coords.x, coords.y, coords.z, 30, 30, 30, 255)
    end

    StopAnimTask(ped, 'skydive@base', 'free_idle', 1.0)
    ClearPedTasks(ped)
    if wall then
        -- mali skok preko ivice
        SetEntityVelocity(ped, -normal.x * 2.5, -normal.y * 2.5, 5.5)
    else
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    end
    Wait(600)
    SetPedCanRagdoll(ped, true)
    busy = false
end

local function loop()
    while equipped do
        Wait(0)
        local ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
            equipped = false
            break
        end
        if not busy then
            local aiming = not Config.RequireAim or IsControlPressed(0, Config.Keys.aim) or IsDisabledControlPressed(0, Config.Keys.aim)
            if aiming then
                local hit, coords, normal = raycast()
                DrawRect(0.5, 0.5, 0.003, 0.005, 255, 255, 255, 220)
                if hit then
                    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 80, 220, 120, 190, false, false, 2, false, nil, nil, false)
                    help('Pritisni ~INPUT_PICKUP~ za grapple')
                    if IsControlJustPressed(0, Config.Keys.grapple) then
                        if GetGameTimer() - lastUse >= Config.Cooldown then
                            dbg('pull', coords, normal)
                            pull(coords, normal)
                        else
                            notify('Grappler se još puni.')
                        end
                    end
                else
                    help('Nema mete u dometu')
                end
            end
        end
    end
end

local function toggle()
    equipped = not equipped
    dbg('equipped', equipped)
    notify(equipped and 'Grappler spreman: drži desni klik, ciljaj i pritisni E.' or 'Grappler spremljen.')
    if equipped then CreateThread(loop) end
end

RegisterNetEvent('grapple:toggle', toggle)
if Config.Command then RegisterCommand(Config.Command, toggle, false) end
