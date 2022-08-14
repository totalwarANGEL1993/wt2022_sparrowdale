-- ************************************************************************************************
-- *                                                                                              *
-- *                                                                                              *
-- *                                              EMS                                             *
-- *                                         CONFIGURATION                                        *
-- *                                                                                              *
-- *                                                                                              *
-- ************************************************************************************************

EMS_CustomMapConfig = {
    -- ********************************************************************************************
    -- * Configuration File Version
    -- * A version check will make sure every player has the same version of the configuration file
    -- ********************************************************************************************
    Version = 1,

    -- ********************************************************************************************
    -- * Callback_OnMapStart
    -- * Called directly after the loading screen vanishes and works as your entry point.
    -- * Similar use to FirstMapAction/GameCallback_OnGameSart
    -- ********************************************************************************************

    Callback_OnMapStart = function()
        local Path = "E:/Siedler/Projekte/xmas2022koth/";
        Script.Load(Path.. "svlib.lua");
        Script.Load(Path.. "comforts.lua");
        Script.Load(Path.. "simplesynchronizer.lua");
        Script.Load(Path.. "capturableoutpost.lua");
        Script.Load(Path.. "deliverycart.lua");
        Script.Load(Path.. "victoryconditions.lua");

        AddPeriodicSummer(60);
        SetupNormalWeatherGfxSet();
        LocalMusic.UseSet = DARKMOORMUSIC;

        -- Deliver resource to the players
        function GameCallback_User_OutpostProduceResource(_ScriptName, _SpawnPoint, _OwningTeam, _ResourceType, _Amount)
            local Sender = WT2022.Outpost.Teams[_OwningTeam].Deliverer;
            local TeamData = WT2022.Outpost.Teams[_OwningTeam];
            local Amount1 = (IsExisting("HQ" ..TeamData[2]) and _Amount/2) or _Amount;
            local Amount2 = (IsExisting("HQ" ..TeamData[1]) and _Amount/2) or _Amount;
            if IsExisting("HQ" ..TeamData[1]) then
                WT2022.Delivery.SendCart(Sender, TeamData[1], _SpawnPoint, _ResourceType, Amount1);
            end
            if IsExisting("HQ" ..TeamData[2]) then
                WT2022.Delivery.SendCart(Sender, TeamData[2], _SpawnPoint, _ResourceType, Amount2);
            end
        end

        -- A resource has been stohlen
        function GameCallback_User_PlayerStoleResource(_Receiver, _Team, _ResourceType, _Amount)
            WT2022.Victory.RegisterTheft(_Team, _Amount);
        end

        -- An outpost was claimed
        function GameCallback_User_OutpostClaimed(_ScriptName, _CapturingPlayer, _TeamOfCapturer, _OutpostPlayerID)
            GUIQuestTools.ToggleStopWatch(0, 0);
            WT2022.Victory.SetTimer(-1);
            WT2022.Victory.RegisterClaim(_TeamOfCapturer, _ScriptName);
            if WT2022.Victory:DoesOneTeamControllAllOutposts() then
                GUIQuestTools.ToggleStopWatch(5*60, 1);
                WT2022.Victory.SetTimer(5*60);
            end
        end

        -- Upgrade of outpost has started
        function GameCallback_User_OutpostUpgradeStarted(_ScriptName, _UpgradeType, _NextUpgradeLevel)
        end

        -- Upgrade of outpost has finished
        function GameCallback_User_OutpostUpgradeFinished(_ScriptName, _UpgradeType, _NewUpgradeLevel)
        end
    end,

    -- ********************************************************************************************
    -- * Callback_OnGameStart
    -- * Called at the end of the 10 seconds delay, after the host chose the rules and started
    -- ********************************************************************************************
    Callback_OnGameStart = function()
    end,

    -- ********************************************************************************************
    -- * Callback_OnPeacetimeEnded
    -- * Called when the peacetime counter reaches zero
    -- ********************************************************************************************
    Callback_OnPeacetimeEnded = function()
        -- Get teams
        local Teams = {[1] = {1, 2}, [2] = {3, 4}};
        if XNetwork.Manager_DoesExist() == 1 then
            Teams = {};
            for i= 1, 4 do
                local Team = XNetwork.GameInformation_GetPlayerTeam(i);
                Teams[Team] = Teams[Team] or {};
                table.insert(Teams[Team], i);
            end
        end
        -- Check teams
        if not AreTeamsValidFor2vs2(Teams) then
            Message("Etwas stimmt nicht mit Team 1!");
            return;
        end
        -- Init systems
        WT2022.Delivery.Init(Teams[1][1], Teams[1][2], 5, Teams[2][1], Teams[2][2], 6);
        WT2022.Outpost.Init(Teams[1][1], Teams[1][2], 5, Teams[2][1], Teams[2][2], 6);
        WT2022.Victory.Init(Teams[1][1], Teams[1][2], 5, Teams[2][1], Teams[2][2], 6);
        -- Create outposts
        WT2022.Outpost.Create("OP1", ResourceType.IronRaw, nil);
        WT2022.Outpost.Create("OP2", ResourceType.ClayRaw, nil);
        WT2022.Victory:SetMaximumOutpostAmount(8);
        WT2022.Victory:SetResourceAmount(5000);
    end,

    -- ********************************************************************************************
    -- * Peacetime
    -- * Number of minutes the players will be unable to attack each other
    -- ********************************************************************************************
    Peacetime = 1,

    -- ********************************************************************************************
    -- * GameMode
    -- * GameMode is a concept of a switchable option, that the scripter can freely use
    -- *
    -- * GameModes is a table that contains the available options for the players, for example:
    -- * GameModes = {"3vs3", "2vs2", "1vs1"},
    -- *
    -- * GameMode contains the index of selected mode by default - ranging from 1 to X
    -- *
    -- * Callback_GameModeSelected
    -- * Lets the scripter make changes, according to the selected game mode.
    -- * You could give different ressources or change the map environment accordingly
    -- * _gamemode contains the index of the selected option according to the GameModes table
    -- ********************************************************************************************
    GameMode = 1,
    GameModes = {"2vs2"},
    Callback_GameModeSelected = function(_gamemode)
    end,

    -- ********************************************************************************************
    -- * Resource Level
    -- * Determines how much ressources the players start with
    -- * 1 = Normal
    -- * 2 = FastGame
    -- * 3 = SpeedGame
    -- * See the ressources table below for configuration
    -- ********************************************************************************************
    ResourceLevel = 1,

    -- ********************************************************************************************
    -- * Resources
    -- * Order:
    -- * Gold, Clay, Wood, Stone, Iron, Sulfur
    -- * Rules:
    -- * 1. If no player is defined, default values are used
    -- * 2. If player 1 is defined, these ressources will be used for all other players too
    -- * 3. Use the players index to give ressources explicitly
    -- ********************************************************************************************    
    Ressources =
    {
        -- * Normal default: 1k, 1.8k, 1.5k, 0.8k, 50, 50
        Normal = {
            [1] = {
                1000,
                1800,
                1500,
                800,
                50,
                50,
            },
        },
        -- * FastGame default: 2 x Normal Ressources
        FastGame = {},

        -- * SpeedGame default: 20k, 12k, 14k, 10k, 7.5k, 7.5k
        SpeedGame = {},
    },

    -- ********************************************************************************************
    -- * Callback_OnFastGame
    -- * Called together with Callback_OnGameStart if the player selected ResourceLevel 2 or 3
    -- * (FastGame or SpeedGame)
    -- ********************************************************************************************
    Callback_OnFastGame = function()
    end,

    -- ********************************************************************************************
    -- * AI Players
    -- * Player Entities that belong to an ID that is also present in the AIPlayers table won't be
    -- * removed
    -- ********************************************************************************************
    AIPlayers = {
        5, 6, 7, 8
    },

    -- ********************************************************************************************
    -- * DisableInitCameraOnHeadquarter
    -- * Set to true if you don't want the camera to be set to the headquarter automatically
    -- * (default: false)
    -- ********************************************************************************************
    DisableInitCameraOnHeadquarter = false,

    -- ********************************************************************************************
    -- * DisableSetZoomFactor
    -- * If set to false, ZoomFactor will be set to 2 automatically
    -- * Set to true if nothing should be done
    -- * (default: false)
    -- ********************************************************************************************
    DisableSetZoomFactor = false,

    -- ********************************************************************************************
    -- * DisableStandardVictoryCondition
    -- * Set to true if you want to implement your own victory condition
    -- * Otherwise the player will lose upon losing his headquarter
    -- * (default: false)
    -- ********************************************************************************************
    DisableStandardVictoryCondition = true,

    -- ********************************************************************************************
    -- * Units
    -- * Various units can be allowed or forbidden
    -- * A 0 means the unit is forbidden - a higher number represents the maximum allowed level
    -- * Example:
    -- * Sword = 0, equals Swords are forbidden
    -- * Sword = 2, equals the maximum level for swords is 2 = Upgrading once
    -- ********************************************************************************************
    Sword        = 4,
    Bow          = 4,
    PoleArm      = 4,
    HeavyCavalry = 2,
    LightCavalry = 2,
    Rifle        = 2,
    Thief        = 1,
    Scout        = 1,
    Cannon1      = 1,
    Cannon2      = 1,
    Cannon3      = 1,
    Cannon4      = 1,

    -- * Buildings
    Bridge = 1,

    -- * Markets
    -- * -1 = Building markets is forbidden
    -- * 0 = Building markets is allowed
    -- * >0 = Markets are allowed and limited to the number given
    Markets = 3,

    -- * Trade Limit
    -- * 0 = no trade limit
    -- * greater zero = maximum amount that you can buy in one single trade
    TradeLimit = 3000,

    -- * TowerLevel
    -- * 0 = Towers forbidden
    -- * 1 = Watchtowers
    -- * 2 = Balistatowers
    -- * 3 = Cannontowers
    TowerLevel = 0, -- 0-3

    -- * TowerLimit
    -- * 0  = no tower limit
    -- * >0 = towers are limited to the number given
    TowerLimit = 5,

    -- * WeatherChangeLockTimer
    -- * Minutes for how long the weather can't be changed directly again after a weatherchange happened
    WeatherChangeLockTimer =  3,

    MakeSummer = 1,
    MakeRain   = 1,
    MakeSnow   = 1,

    -- * Fixes the DestrBuild bug
    AntiBug    = 1,

    -- * HQRush
    -- * If set to true, Headquarters are invulernerable as long the player still has village centers
    HQRush     = 1,
    BlessLimit = 2,

    Heroes = {3,3,3,3},

    -- * Heroes
    Dario              = 1,
    Pilgrim            = 1,
    Ari                = 1,
    Erec               = 1,
    Salim              = 1,
    Helias             = 1,
    Drake              = 1,
    Yuki               = 1,
    Kerberos           = 1,
    Varg               = 1,
    Mary_de_Mortfichet = 1,
    Kala               = 1,
};

-- -------------------------------------------------------------------------- --

function AreTeamsValidFor2vs2(_TeamData)
    if not _TeamData[1] or table.getn(_TeamData[1]) ~= 2 then
        return false;
    end
    if not _TeamData[2] or table.getn(_TeamData[2]) ~= 2 then
        return false;
    end
    return true;
end

-- -------------------------------------------------------------------------- --

