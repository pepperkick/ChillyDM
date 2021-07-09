#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION  "1.1.2"

/* =============== | PLUGIN INFO | =============== */

public Plugin myinfo =
{
    name             = "ChillyDM",
    author           = "PepperKick - fixed by stephanie",
    description      = "A plugin to work with classic DM plugin to add free-for-all features",
    version          =  PLUGIN_VERSION,
    url              = "https://steamcommunity.com/id/pepperkick/"
}

/* =============== | PLUGIN VARIABLES | =============== */

// Stores if friendly fire is enabled globally
bool g_bFriendlyFireOn = false;
// Stores if client has lag compenstation enabled
bool g_bPlayerLagCompensation[MAXPLAYERS + 1];
 // Stores number of players currently in lag compenstation
int g_iLagCompenstationCount = 0;

// List of projectile classes to track for
static const char g_aProjectileClasses[][] =
{
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
    "tf_projectile_pipe_remote",
    "tf_projectile_syringe"
};

// stolen from here https://forums.alliedmods.net/showthread.php?t=314271
#define TEAM_CLASSNAME "tf_team"

Handle g_hSDKTeamAddPlayer;
Handle g_hSDKTeamRemovePlayer;
Handle g_cvFriendlyFire = INVALID_HANDLE;


/* =============== v PLUGIN EVENT FUNCTIONS v =============== */

/* OnPluginStart
    | Plugin Event
    | Executed when plugin starts
--------------------------------------------- */
public void OnPluginStart()
{
    Handle hGameData = LoadGameConfigFile("chillygamedata");

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTeam::AddPlayer");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    g_hSDKTeamAddPlayer = EndPrepSDKCall();
    if(g_hSDKTeamAddPlayer == INVALID_HANDLE)
        SetFailState("Could not find CTeam::AddPlayer!");

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTeam::RemovePlayer");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    g_hSDKTeamRemovePlayer = EndPrepSDKCall();
    if(g_hSDKTeamRemovePlayer == INVALID_HANDLE)
        SetFailState("Could not find CTeam::RemovePlayer!");

    delete hGameData;

    CreateConVar(
        "chillydm_version",
        PLUGIN_VERSION,
        "ChillyDM Plugin Version",
        FCVAR_SPONLY
    );

    g_cvFriendlyFire = FindConVar("mp_friendlyfire");
    UpdateFriendlyFireStatus();

    // Event Hooks
    HookConVarChange(g_cvFriendlyFire, Hook_CvarFriendlyFireChanger);      // Cvar change hook for friendly fire

    AddTempEntHook("Fire Bullets", Hook_TEFireBullets);                    // Bullet fire hook

    HookEvent("player_spawn", Hook_PlayerSpawn);                           // Event hook for player spwan
    HookEvent("player_death", Hook_PlayerDeath_Pre, EventHookMode_Pre);    // Event hook for player death pre

    AddCommandListener(Command_JoinTeam, "jointeam");                      // Command hook for player jointeam

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage,  Hook_OnTakeDamage);
            SDKHook(i, SDKHook_ShouldCollide, Hook_ClientShouldCollide);
        }
    }
}

/* OnClientPutInServer
    | Plugin Event
    | Executed when a client is fully in server
--------------------------------------------- */
public void OnClientPutInServer(int client)
{
    if (IsValidClient(client) && g_bFriendlyFireOn)
    {
        SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        TF2_ChangeClientTeam(client, TFTeam_Red);
        DisableLagCompensation(client);
        ShowVGUIPanel(client, "class_red");
    }
}

/* OnEntityCreated
    |
    | Executed when an entity gets created in game
    | ( this is way cheaper than OnGameFrame)
--------------------------------------------- */
public void OnEntityCreated(int entity, const char[] classname)
{
    if (g_bFriendlyFireOn)
    {
        for (int i = 0; i < sizeof(g_aProjectileClasses); i++)
        {
            // does it match any of the ents?
            if (StrEqual(classname, g_aProjectileClasses[i]))
            {
                RequestFrame(NextFrameFixProjectile, EntIndexToEntRef(entity));
            }
        }
    }
}

void NextFrameFixProjectile(int entity)
{
    if (IsValidEntity(entity))
    {
        entity = EntRefToEntIndex(entity);
        SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", 0);
        SetEntProp(entity, Prop_Send, "m_iTeamNum", 3);
    }
}


/* =============== ^ PLUGIN EVENT FUNCTIONS ^ =============== */

/* =============== v HOOK EVENT FUNCTIONS v =============== */

/* Hook_CvarFriendlyFireChanger
    | Hook Event
    | Executed when cvar is changed
--------------------------------------------- */
public void Hook_CvarFriendlyFireChanger(Handle convar, const char[] oldValue, const char[] newValue)
{
    UpdateFriendlyFireStatus();
    UpdateTeamCollision();
    ExecuteConfig();
}

/* Event_PlayerSpawn
    | Hook Event
    | Executed when a player spawns
--------------------------------------------- */
public Action Hook_PlayerSpawn(Handle event, const char[] name, bool dB)
{
    if (!g_bFriendlyFireOn)
    {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsValidClient(client))
    {
        DisableLagCompensation(client);
        TF2_ChangeClientTeam(client, TFTeam_Red);
    }
    return Plugin_Continue;
}

/* Hook_PlayerDeath_Pre
    | Hook Event
    | Executed before player death event is fired
--------------------------------------------- */
public Action Hook_PlayerDeath_Pre(Handle event, const char[] name, bool dB)
{
    if (!g_bFriendlyFireOn)
    {
        return Plugin_Continue;
    }

    int victim   = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (IsValidClient(victim))
    {
        DisableLagCompensation(victim);
    }

    if (IsValidClient(attacker))
    {
        DisableLagCompensation(attacker);
    }

    if (victim != attacker)
    {
        CreateTimer(0.1, Timer_FixKills, attacker);
    }

    return Plugin_Continue;
}

public Action Timer_FixKills(Handle timer, int attacker)
{
    if (IsValidClient(attacker))
    {
        SetEntProp(attacker, Prop_Data, "m_iFrags", GetEntProp(attacker, Prop_Send, "m_iKills"));
    }
}

/* Hook_TEFireBullets
    | Hook Event
    | Executed when a player shoots
--------------------------------------------- */
public Action Hook_TEFireBullets(const char[] te_name, const int[] Players, int numClients, float delay)
{
    if (!g_bFriendlyFireOn)
    {
        return Plugin_Continue;
    }

    int client = TE_ReadNum("m_iPlayer") + 1;

    if (IsValidClient(client))
    {
        EnableLagCompensation(client);
        RequestFrame(NextFrameDisableLagComp, client);
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

void NextFrameDisableLagComp(int client)
{
    DisableLagCompensation(client);
}

/* Hook_OnTakeDamage
    | Hook Event
    | Executed when a player takes damage
--------------------------------------------- */
public Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (!g_bFriendlyFireOn)
    {
        return Plugin_Continue;
    }
    if (IsValidClient(attacker))
    {
        DisableLagCompensation(attacker);
    }
    return Plugin_Continue;
}

/* Hook_ClientShouldCollide
    | Hook Event
    | Executed when game tries to check if
     players can collide
---------------------------------------------
*/
public bool Hook_ClientShouldCollide(int ent, int collisiongroup, int contentsmask, bool originalResult)
{
    return g_bFriendlyFireOn ? true : originalResult;
}


/* Command_JoinTeam
    | Command Event
    | Executed when player tries to join
     a team
--------------------------------------------- */
public Action Command_JoinTeam(int client, const char[] command, int argc)
{
    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));

    if (g_bFriendlyFireOn)
    {
        if (StrEqual(arg, "red", false))
        {
            return Plugin_Continue;
        }
        else
        {
            PrintToChat(client, "Team Change Blocked!");
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
void UpdateFriendlyFireStatus()
{
    g_bFriendlyFireOn = GetConVarBool(g_cvFriendlyFire);
}

/* UpdateTeamCollision
    | Public Function
    | Updates the value of team collision
--------------------------------------------- */
void UpdateTeamCollision()
{
    SetConVarInt(FindConVar("tf_avoidteammates"), g_bFriendlyFireOn ? 0 : 1);
}

/* ClientEnableFakeLagCompensation
    | Public Function
    | Enables lag compenstation for player
    ===== Parameters
        | (int) client
--------------------------------------------- */
void EnableLagCompensation(int client)
{
    if
    (
        g_bPlayerLagCompensation[client]
        // this prevents the map restarting when a single player is on the server
        || GetClientCount() == 1
        || GetClientCount() - 1 == g_iLagCompenstationCount
    )
    {
        return;
    }
    ChangeClientTeamEx(client, 0);
    g_bPlayerLagCompensation[client] = true;
    g_iLagCompenstationCount++;
}

/* ClientDisableFakeLagCompensation
    | Public Function
    | Disables lag compenstation for player
    ===== Parameters
        | (int) client
--------------------------------------------- */
void DisableLagCompensation(int client)
{
    if
    (
        g_bPlayerLagCompensation[client]
        // this prevents the map restarting when a single player is on the server
        || GetClientCount() == 1
        || GetClientCount() - 1 == g_iLagCompenstationCount
    )
    {
        return;
    }
    ChangeClientTeamEx(client, 2);
    g_bPlayerLagCompensation[client] = false;
    g_iLagCompenstationCount--;
}

/* ExecuteConfig
    | Public Function
    | Executes config if friendly fire value
     changes
--------------------------------------------- */
void ExecuteConfig()
{
    if (g_bFriendlyFireOn)
    {
        ServerCommand("exec chillydm/ffa");
    }
    else
    {
        ServerCommand("exec chillydm/tdm");
    }
}

/* =============== ^ FUNCTIONS ^ =============== */

/* =============== | OTHER FUNCTIONS | =============== */

bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        // don't bother sdkhooking stv or replay bots lol
        && !IsClientSourceTV(client)
        && !IsClientReplay(client)
    );
}

void ChangeClientTeamEx(int iClient, int iNewTeamNum)
{
    int iTeamNum = GetEntProp(iClient, Prop_Send, "m_iTeamNum");

    // Safely swap team
    int iTeam = MaxClients+1;
    while ((iTeam = FindEntityByClassname(iTeam, TEAM_CLASSNAME)) != -1)
    {
        int iAssociatedTeam = GetEntProp(iTeam, Prop_Send, "m_iTeamNum");
        if (iAssociatedTeam == iTeamNum)
            SDK_Team_RemovePlayer(iTeam, iClient);
        else if (iAssociatedTeam == iNewTeamNum)
            SDK_Team_AddPlayer(iTeam, iClient);
    }

    SetEntProp(iClient, Prop_Send, "m_iTeamNum", iNewTeamNum);
}

void SDK_Team_AddPlayer(int iTeam, int iClient)
{
    if (g_hSDKTeamAddPlayer != INVALID_HANDLE)
    {
        SDKCall(g_hSDKTeamAddPlayer, iTeam, iClient);
    }
}

void SDK_Team_RemovePlayer(int iTeam, int iClient)
{
    if (g_hSDKTeamRemovePlayer != INVALID_HANDLE)
    {
        SDKCall(g_hSDKTeamRemovePlayer, iTeam, iClient);
    }
}