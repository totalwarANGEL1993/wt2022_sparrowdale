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
        AddPeriodicSummer(60);
        SetupNormalWeatherGfxSet();
        AddPeriodicSummer(300);
        AddPeriodicRain(120);
        LocalMusic.UseSet = DARKMOORMUSIC;

        StartSimpleJob("OutpostPitFiller");
        MakeBlockRocksInvisible();
        CreateWoodpilesForPlayers();

        Display.SetPlayerColorMapping(7, 14);
        Display.SetPlayerColorMapping(8, 14);

        for i= 1, 4 do
            VictoryConditionQuestDomincance(i);
            VictoryConditionQuestTactical(i);
            VictoryConditionQuestThievery(i);
        end

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
        function GameCallback_User_OutpostClaimed(_ScriptName, _OldPlayer, _NewPlayer, _TeamOfCapturer, _OutpostPlayerID)
            GUIQuestTools.ToggleStopWatch(0, 0);
            WT2022.Victory.SetTimer(-1);
            WT2022.Victory.RegisterClaim(_NewPlayer, _ScriptName);
            if WT2022.Victory:DoesOneTeamControllAllOutposts() then
                GUIQuestTools.ToggleStopWatch(5*60, 1);
                WT2022.Victory.SetTimer(5*60);
            end
            WT2022.Victory:CreateCompensationHeap(_ScriptName, _OldPlayer, _NewPlayer);
        end

        -- Upgrade of outpost has started
        function GameCallback_User_OutpostUpgradeStarted(_ScriptName, _UpgradeType, _NextUpgradeLevel)
            OnOutpostUpgradeStarted(_ScriptName, _UpgradeType, _NextUpgradeLevel);
        end

        -- Upgrade of outpost has finished
        function GameCallback_User_OutpostUpgradeFinished(_ScriptName, _UpgradeType, _NewUpgradeLevel)
            OnOutpostUpgradeFinished(_ScriptName, _UpgradeType, _NewUpgradeLevel);
        end

        -- A player was defeated
        function GameCallback_User_PlayerDefeated(_PlayerID, _Team)
            if not WT2022.Victory.Teams[_Team] then
                return;
            end
            local Index = (WT2022.Victory.Teams[_Team][1] == _PlayerID and 2) or 1;
            local NewPlayer = WT2022.Victory.Teams[_Team][Index];
            if Logic.PlayerGetGameState(NewPlayer) == 1 then
                for i= 1, 8 do
                    if Logic.EntityGetPlayer(GetID("OP" ..i)) == _PlayerID then
                        WT2022.Outpost.Claim("OP" ..i, NewPlayer);
                    end
                end
            end
        end
    end,

    -- ********************************************************************************************
    -- * Callback_OnGameStart
    -- * Called at the end of the 10 seconds delay, after the host chose the rules and started
    -- ********************************************************************************************
    Callback_OnGameStart = function()
        -- Can not make snow during peacetime
        for i= 1, 4 do
            ForbidTechnology(Technologies.T_MakeSnow, i);
        end

        AI.Player_EnableAi(7);
        for i= 1, 8 do
            MakeInvulnerable("OP" ..i);
        end

        RemoveBlockRocksToMakeOutpostsAccessable();

        -- Get teams
        local Teams = {[1] = {1, 2}, [2] = {3, 4}};
        -- Setup outposts
        WT2022.Delivery.Init(Teams[1][1], Teams[1][2], 5, Teams[2][1], Teams[2][2], 6);
        WT2022.Outpost.Init(Teams[1][1], Teams[1][2], 5, Teams[2][1], Teams[2][2], 6);
        WT2022.Outpost.Create("OP1", ResourceType.SulfurRaw, "Oxford");
        WT2022.Outpost.Create("OP2", ResourceType.IronRaw,   "Cheltenham");
        WT2022.Outpost.Create("OP3", ResourceType.IronRaw,   "Cambridge");
        WT2022.Outpost.Create("OP4", ResourceType.SulfurRaw, "Norwich");
        WT2022.Outpost.Create("OP5", ResourceType.StoneRaw,  "Reading");
        WT2022.Outpost.Create("OP6", ResourceType.ClayRaw,   "Southampton");
        WT2022.Outpost.Create("OP7", ResourceType.ClayRaw,   "Birmingham");
        WT2022.Outpost.Create("OP8", ResourceType.StoneRaw,  "Peterborough");
        -- Setup victory conditions
        WT2022.Victory.Init(Teams[1][1], Teams[1][2], 5, Teams[2][1], Teams[2][2], 6);
        WT2022.Victory:SetMaximumOutpostAmount(8);
        WT2022.Victory:SetResourceAmount(5000);
    end,

    -- ********************************************************************************************
    -- * Callback_OnPeacetimeEnded
    -- * Called when the peacetime counter reaches zero
    -- ********************************************************************************************
    Callback_OnPeacetimeEnded = function()
        RemoveBlockRocksToMakePlayersAccessEachother();
        -- Change weather for blocking reasons
        if Logic.GetWeatherState() == 1 then
            StartRain(30);
        else
            StartSummer(30);
        end

        -- Allow make snow
        for i= 1, 4 do
            AllowTechnology(Technologies.T_MakeSnow, i);
        end
    end,

    -- ********************************************************************************************
    -- * Peacetime
    -- * Number of minutes the players will be unable to attack each other
    -- ********************************************************************************************
    Peacetime = 30,

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
                1200,
                2000,
                1500,
                1200,
                150,
                150,
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
    TowerLevel = 1, -- 0-3

    -- * TowerLimit
    -- * 0  = no tower limit
    -- * >0 = towers are limited to the number given
    TowerLimit = 0,

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

function OutpostPitFiller()
    for i= 1, 8 do
        if IsExisting("OP" ..i.. "_Pit") then
            if IsExisting("OP" ..i.. "_Mine") then
                local ID = GetID("OP" ..i.. "_Pit");
                if Logic.GetResourceDoodadGoodAmount(ID) < 999999 then
                    Logic.SetResourceDoodadGoodAmount(ID, 999999);
                end
            else
                DestroyEntity("OP" ..i.. "_Pit");
            end
        end
    end
end

function CreateWoodpilesForPlayers()
    for i= 1, 4 do
        CreateWoodPile("WoodPile1_P"..i, 25000);
        CreateWoodPile("WoodPile2_P"..i, 25000);
    end
end

function MakeBlockRocksInvisible()
    Logic.SetModelAndAnimSet(GetID("RockBlock0_1"), Models.Effects_XF_ExtractStone);
    Logic.SetModelAndAnimSet(GetID("RockBlock0_2"), Models.Effects_XF_ExtractStone);
    for i= 1, 4 do
        for j= 1, 6 do
            Logic.SetModelAndAnimSet(GetID("RockBlock" ..i.. "_" ..j), Models.Effects_XF_ExtractStone);
        end
    end
end

function RemoveBlockRocksToMakeOutpostsAccessable()
    DestroyEntity("RockBlock1_6");
    DestroyEntity("RockBlock1_5");
    DestroyEntity("RockBlock1_3");
    DestroyEntity("RockBlock1_2");
    DestroyEntity("RockBlock2_5");
    DestroyEntity("RockBlock2_4");
    DestroyEntity("RockBlock2_3");
    DestroyEntity("RockBlock2_2");
    DestroyEntity("RockBlock3_6");
    DestroyEntity("RockBlock3_5");
    DestroyEntity("RockBlock3_2");
    DestroyEntity("RockBlock3_1");
    DestroyEntity("RockBlock4_6");
    DestroyEntity("RockBlock4_5");
    DestroyEntity("RockBlock4_3");
    DestroyEntity("RockBlock4_1");
end

function RemoveBlockRocksToMakePlayersAccessEachother()
    DestroyEntity("RockBlock0_1");
    DestroyEntity("RockBlock0_2");
    DestroyEntity("RockBlock1_4");
    DestroyEntity("RockBlock1_1");
    DestroyEntity("RockBlock2_6");
    DestroyEntity("RockBlock2_1");
    DestroyEntity("RockBlock3_4");
    DestroyEntity("RockBlock3_3");
    DestroyEntity("RockBlock4_4");
    DestroyEntity("RockBlock4_2");
end

function OnOutpostUpgradeStarted(_ScriptName, _UpgradeType, _NextUpgradeLevel)
    -- TODO (will propably never be done...)
end

function OnOutpostUpgradeFinished(_ScriptName, _UpgradeType, _NewUpgradeLevel)
    -- TODO (will propably never be done...)
end

function VictoryConditionQuestDomincance(_PlayerID)
    local Title = "Siegbedingung: AUSLÖSCHUNG";
    local Text  = "Das Team dem es gelingt, das gegnerische Team zu "..
                  "vernichten, hat gewonnen. @cr @cr Hinweise: @cr @cr "..
                  "1) Ob schnelle Siege wie z.B. durch Rush möglich sind "..
                  "oder nicht, hängt von den EMS-Einstellungen ab. @cr "..
                  "2) Gebäude in der Basis können nicht zerstört werden, "..
                  "solange noch Außenposten kontrolliert werden.";
    Logic.AddQuest(_PlayerID, 1, MAINQUEST_OPEN, Title, Text, 1);
end

function VictoryConditionQuestTactical(_PlayerID)
    local Title = "Siegbedingung: VORHERRSCHAFT";
    local Text  = "Das Team dem es gelingt, alle Außenposten zu erobern "..
                  "und 5 Minuten zu halten, hat gewonnen."..
                  " @cr @cr Hinweise: @cr @cr "..
                  "1) Außenposten werden beansprucht, in dem sie zu einem "..
                  " gewissen Grad beschädigt werden. @cr "..
                  "2) Gebäude in der Basis können nicht zerstört werden, "..
                  "solange noch Außenposten kontrolliert werden. @cr "..
                  "3) Außenposten produzieren veredelbare Rohstoffe und"..
                  " können durch Upgrades verbessert werden. @cr "..
                  "4) Eine Lieferung umfasst 250 Rohstoffe (oder 500 wenn "..
                  "der Teampartner bereits verloren hat).";
    Logic.AddQuest(_PlayerID, 2, MAINQUEST_OPEN, Title, Text, 1);
end

function VictoryConditionQuestThievery(_PlayerID)
    local Title = "Siegbedingung: DIEBESKUNST";
    local Text  = "Das Team dem es gelingt, Warenlieferungen von 10000 "..
                  "Einheiten zu erbeuten, hat gewonnen."..
                  " @cr @cr Hinweise: @cr @cr "..
                  "1) Diebe können Handelskarren angreifen, wodurch diese "..
                  "den Besitzer und ihr Ziel wechseln. @cr "..
                  "2) Eine Lieferung umfasst 250 Rohstoffe (oder 500 wenn "..
                  "der Teampartner bereits verloren hat).";
    Logic.AddQuest(_PlayerID, 3, MAINQUEST_OPEN, Title, Text, 1);
end

