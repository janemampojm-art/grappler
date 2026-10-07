local ESX = exports['es_extended']:getSharedObject()

exports('grappler', function(event, item, inventory, slot, data)
    if event ~= 'usingItem' then return end

    local src = inventory.id
    local x = ESX.GetPlayerFromId(src)
    if not x then return false end

    if Config.Jobs then
        local ok = false
        for _, j in ipairs(Config.Jobs) do
            if x.job.name == j then ok = true break end
        end
        if not ok then
            x.showNotification('Ne znaš koristiti ovo.')
            return false
        end
    end

    TriggerClientEvent('grapple:toggle', src)
end)
