----------------------------------------------------------------------
-- BoneyardTBC Core
-- Module registry, saved variables, and slash commands
----------------------------------------------------------------------

BoneyardTBC = {}
BoneyardTBC.modules = {}
BoneyardTBC.initialized = false

-- Module alias map: slash command shorthand -> registered module name
BoneyardTBC.moduleAliases = {
    ["do"] = "DungeonOptimizer",
}

----------------------------------------------------------------------
-- Module Registry
----------------------------------------------------------------------

function BoneyardTBC:RegisterModule(name, module)
    if self.modules[name] then
        print("|cffff6600BoneyardTBC:|r Module '" .. name .. "' is already registered.")
        return
    end
    self.modules[name] = module

    -- If core already initialized (module loaded after ADDON_LOADED),
    -- immediately initialize this module with its DB namespace.
    if self.initialized and BoneyardTBCDB then
        if not BoneyardTBCDB[name] then
            BoneyardTBCDB[name] = {}
        end
        if module.OnInitialize then
            module:OnInitialize(BoneyardTBCDB[name])
        end
    end
end

function BoneyardTBC:GetModule(name)
    return self.modules[name]
end

----------------------------------------------------------------------
-- Saved Variables — Defaults Merging
----------------------------------------------------------------------

local DEFAULTS = {
    core = {
        minimapButtonAngle = 220,
        windowPosition = { point = "CENTER", x = 0, y = 0 },
        windowSize = { width = 700, height = 580 },
    },
}

-- Recursively fill missing keys in `target` from `source` without
-- overwriting existing values.
local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                MergeDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            MergeDefaults(target[k], v)
        end
    end
end

----------------------------------------------------------------------
-- Initialization (ADDON_LOADED)
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "BoneyardTBC" then
        -- Initialize saved variables with defaults
        if not BoneyardTBCDB then
            BoneyardTBCDB = {}
        end
        MergeDefaults(BoneyardTBCDB, DEFAULTS)

        -- Notify all registered modules
        for name, module in pairs(BoneyardTBC.modules) do
            -- Ensure a namespace exists for the module in the DB
            if not BoneyardTBCDB[name] then
                BoneyardTBCDB[name] = {}
            end
            if module.OnInitialize then
                module:OnInitialize(BoneyardTBCDB[name])
            end
        end

        BoneyardTBC.initialized = true
        self:UnregisterEvent("ADDON_LOADED")

        -- Register with Mechanic (safe if Mechanic isn't installed)
        if MechanicLib then
            MechanicLib:RegisterAddon("BoneyardTBC", {
                tests = true,
                console = true,
                perf = true,
            })
        end

        print("|cff00ccffBoneyard TBC Special|r loaded. Type |cff00ff00/btbc|r for options.")
    end
end)

----------------------------------------------------------------------
-- Slash Commands
----------------------------------------------------------------------

SLASH_BONEYARDTBC1 = "/btbc"

SlashCmdList["BONEYARDTBC"] = function(msg)
    msg = msg or ""
    local args = {}
    for word in msg:gmatch("%S+") do
        args[#args + 1] = word
    end

    -- No arguments: toggle the main window
    if #args == 0 then
        if BoneyardTBC.MainFrame and BoneyardTBC.MainFrame.Toggle then
            BoneyardTBC.MainFrame:Toggle()
        else
            print("|cff00ccffBoneyard TBC Special|r — UI not yet loaded.")
        end
        return
    end

    -- First argument is a module name or alias
    local moduleKey = args[1]:lower()
    local moduleName = BoneyardTBC.moduleAliases[moduleKey] or moduleKey

    -- Try to find the module (case-insensitive lookup)
    local targetModule
    for name, mod in pairs(BoneyardTBC.modules) do
        if name:lower() == moduleName:lower() then
            targetModule = mod
            break
        end
    end

    if targetModule then
        -- Remove the module name from args and pass the rest
        table.remove(args, 1)
        local remaining = table.concat(args, " ")
        if targetModule.OnSlashCommand then
            targetModule:OnSlashCommand(remaining)
        end
    else
        print("|cff00ccffBoneyard TBC Special|r — Unknown module: " .. args[1])
        print("  Usage: /btbc — toggle main window")
        print("  Usage: /btbc <module> <args> — run module command")
    end
end
