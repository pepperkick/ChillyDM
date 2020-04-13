#define PLUGIN_VERSION  "1.0.1"
#define UPDATE_URL      ""
#define TAG             "CHILLY"
#define COLOR_TAG       "{matAmber}"
#define MAX_PLAYERS     36
#define DEBUG
#define DEBUG_TAG       "DM"

/* =============== | PLUGIN INFO | =============== */

public Plugin:myinfo = {
    name = "ChillyDM",
    author = "PepperKick",
    description = "A plugin to work with classic DM plugin to add new features",
    version = PLUGIN_VERSION,
    url = "https://steamcommunity.com/id/pepperkick/"
}

/* =============== | PLUGIN VARIABLES | =============== */

Handle g_tPlayerChangeTeamTimes
        [MAXPLAYERS+1];                 // Stores all timers for player change team

bool g_bFriendlyFireOn = false;         // Stores weather friendly fire is enabled
bool g_bPlayerLagCompensation
        [MAXPLAYERS + 1] = false;       // Stores weather player has lag compenstation enabled

int  g_iLagCompenstationCount = 0;      // Stores number of players in lag compenstation

// List of projectile classes to track for
static const String:g_aProjectileClasses[][] = {
    "tf_projectile_rocket",
    "tf_projectile_sentryrocket",
    "tf_projectile_arrow",
    "tf_projectile_stun_ball",
    "tf_projectile_ball_ornament",
    "tf_projectile_energy_ball",
    "tf_projectile_energy_ring",
    "tf_projectile_flare",
    "tf_projectile_healing_bolt",
    "tf_projectile_jar",
    "tf_projectile_jar_milk",
    "tf_projectile_pipe",
    "tf_projectile_syringe"
};

#include <headers>

/* =============== v PLUGIN EVENT FUNCTIONS v =============== */

/* OnPluginStart
    | Plugin Event
    | Executed when plugin starts
--------------------------------------------- */
public OnPluginStart() {
    CreateCvars();               
    UpdateFriendlyFireStatus();    

    // Event Hooks
    HookConVarChange(g_cvFriendlyFire, Hook_CvarFriendlyFireChanger);       // Cvar change hook for friendly fire

    AddTempEntHook("Fire Bullets", Hook_TEFireBullets);                     // Bullet fire hook

    HookEvent("player_spawn", Hook_PlayerSpawn);                           // Event hook for player spwan
    HookEvent("player_death", Hook_PlayerDeath_Pre, EventHookMode_Pre);    // Event hook for player death pre

    AddCommandListener(Command_JoinTeam, "jointeam");                      // Command hook for player jointeam

    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage,  Hook_OnTakeDamage);
            SDKHook(i, SDKHook_ShouldCollide, Hook_ClientShouldCollide);
        }
    }

    Debug("Loaded ChillyComp plugin, Version %s", PLUGIN_VERSION);
}

/* OnClientPostAdminCheck
    | Plugin Event
    | Executed when a client is checked for
     admin
--------------------------------------------- */
public OnClientPostAdminCheck(client) {
    if (IsValidClient(client) && g_bFriendlyFireOn) {
        ChangeClientTeam(client, TEAM_RED);

        SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);

        DisableLagCompensation(client);

        ShowVGUIPanel(client, PANEL_CLASS_RED)
    }
}

/* OnClientDisconnect_Post
    | Plugin Event
    | Executed when a client is disconnected
--------------------------------------------- */
public OnClientDisconnect_Post(client) {
    if (g_bFriendlyFireOn) {
        SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
    }
}

/* OnGameFrame
    | Plugin Event
    | Executed when a frame changes in game
--------------------------------------------- */
public OnGameFrame() {
    if (g_bFriendlyFireOn) {
        for (int i = 0; i < sizeof(g_aProjectileClasses); i++) {
            new ent = -1;

            while ((ent = FindEntityByClassname(ent, g_aProjectileClasses[i])) != -1) {
                SetEntProp(ent, Prop_Data, "m_iInitialTeamNum", 0);
                SetEntProp(ent, Prop_Send, "m_iTeamNum", 0);
            }
        }
    }
} 

/* =============== ^ PLUGIN EVENT FUNCTIONS ^ =============== */

/* =============== v HOOK EVENT FUNCTIONS v =============== */

/* Hook_CvarFriendlyFireChanger
    | Hook Event
    | Executed when cvar is changed
--------------------------------------------- */
public Hook_CvarFriendlyFireChanger(Handle:convar, const String:oldValue[], const String:newValue[]) {
    UpdateFriendlyFireStatus();
    UpdateTeamCollision();
    ExecuteConfig();
}

/* Event_PlayerSpawn
    | Hook Event
    | Executed when a player spawns
--------------------------------------------- */
public Action Hook_PlayerSpawn(Handle:event, const String:name[], bool:dB) {
    if (!g_bFriendlyFireOn) return Plugin_Continue;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if(IsValidClient(client))
        DisableLagCompensation(client);

    SetEntProp(client, Prop_Send, "m_iTeamNum", TEAM_RED);

    return Plugin_Continue;
}

/* Hook_PlayerDeath_Pre
    | Hook Event
    | Executed before player death event is fired
--------------------------------------------- */
public Action Hook_PlayerDeath_Pre(Handle:event, const String:name[], bool:dB) {
    if (!g_bFriendlyFireOn) return Plugin_Continue;

    int victim   = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if(IsValidClient(victim))
        DisableLagCompensation(victim);

    if(IsValidClient(attacker))
        DisableLagCompensation(attacker);

    if (victim != attacker) {        
        SetEntProp(victim, Prop_Send, "m_iTeamNum", 0);

        g_tPlayerChangeTeamTimes[victim] = CreateTimer(0.5, Timer_SwitchTeam, victim);
    }

    return Plugin_Continue;
}

/* Hook_TEFireBullets
    | Hook Event
    | Executed when a player shoots
--------------------------------------------- */
public Action Hook_TEFireBullets(const String:te_name[], const Players[], numClients, Float:delay) {
    if (!g_bFriendlyFireOn) return Plugin_Continue;

    new client = TE_ReadNum("m_iPlayer") + 1;

    if (IsValidClient(client)) {
        EnableLagCompensation(client);
    }

    g_tPlayerChangeTeamTimes[client] = CreateTimer(0.1, Timer_SwitchTeam, client);

    return Plugin_Continue;
}

/* Hook_OnTakeDamage
    | Hook Event
    | Executed when a player takes damage
--------------------------------------------- */
public Action Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
    if (!g_bFriendlyFireOn) return Plugin_Continue;

    if (IsValidClient(attacker))
        DisableLagCompensation(attacker);

    return Plugin_Continue;
}

/* Hook_ClientShouldCollide
    | Hook Event
    | Executed when game tries to check if
     players can collide
--------------------------------------------- */
public bool:Hook_ClientShouldCollide(ent, collisiongroup, contentsmask, bool:originalResult) {
    return g_bFriendlyFireOn ? true : originalResult;
}

/* Timer_SwitchTeam
    | Timer Event
    | Executed to disable lag compenstation
     for a player
--------------------------------------------- */
public Action Timer_SwitchTeam(Handle timer, any client) {
    DisableLagCompensation(client);

    g_tPlayerChangeTeamTimes[client] = INVALID_HANDLE;
}

/* Command_JoinTeam
    | Command Event
    | Executed when player tries to join
     a team
--------------------------------------------- */
public Action:Command_JoinTeam(client, const String:command[], argc) {
    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));

    if (g_bFriendlyFireOn) {
        if (StrEqual(arg, "red", false)) {
            return Plugin_Continue;
        } else {
            CPrintToChat(client, "%s[%s] %t", COLOR_TAG, TAG, "TeamChangeBlocked");
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

/* =============== ^ HOOK EVENT FUNCTIONS ^ =============== */

/* =============== v FUNCTIONS v =============== */

/* UpdateFriendlyFireStatus
    | Public Function
    | Updates the status of friendly fire
--------------------------------------------- */
UpdateFriendlyFireStatus() {
    g_bFriendlyFireOn = GetConVarBool(g_cvFriendlyFire);
}

/* UpdateTeamCollision
    | Public Function
    | Updates the value of team collision
--------------------------------------------- */
UpdateTeamCollision() {
    SetConVarInt(FindConVar("tf_avoidteammates"), g_bFriendlyFireOn ? 0 : 1);
}

/* ClientEnableFakeLagCompensation
    | Public Function
    | Enables lag compenstation for player
    ===== Parameters
        | (int) client
--------------------------------------------- */
EnableLagCompensation(client) {
    if (g_bPlayerLagCompensation[client]) return;
    
    if (GetClientCount() == 1) return;

    if (GetClientCount() - 1 == g_iLagCompenstationCount) return;

    SetEntProp(client, Prop_Send, "m_iTeamNum", 0);
    g_bPlayerLagCompensation[client] = true;
    g_iLagCompenstationCount++;
}

/* ClientDisableFakeLagCompensation
    | Public Function
    | Disables lag compenstation for player
    ===== Parameters
        | (int) client
--------------------------------------------- */
DisableLagCompensation(client) {
    if (!g_bPlayerLagCompensation[client]) return;

    SetEntProp(client, Prop_Send, "m_iTeamNum", 2);
    g_bPlayerLagCompensation[client] = false;
    g_iLagCompenstationCount--;
}

/* ExecuteConfig
    | Public Function
    | Executes config if friendly fire value
     changes
--------------------------------------------- */
ExecuteConfig() {
    if (g_bFriendlyFireOn)
        ServerCommand("exec chillydm/ffa");
    else
        ServerCommand("exec chillydm/tdm");
}

/* =============== ^ FUNCTIONS ^ =============== */

/* =============== | OTHER FUNCTIONS | =============== */

stock bool:IsValidClient(iClient) {
    return bool:(0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}

public Debug(const char[] myString, any ...) {
    #if defined DEBUG
        int len = strlen(myString) + 255;
        char[] myFormattedString = new char[len];
        VFormat(myFormattedString, len, myString, 2);

        PrintToServer("[%s] %s", DEBUG_TAG, myFormattedString);
    #endif
}
