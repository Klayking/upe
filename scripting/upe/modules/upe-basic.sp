#pragma semicolon 1

#include <sourcemod>
#include <upe>
#include <tf2>
#include <tf2_stocks>

new bool:tf = false;
new Float:g_basespeed[10] = {0.0, 400.0, 300.0, 240.0, 280.0, 320.0, 230.0, 300.0, 300.0, 300.0};

public OnPluginStart()
{
	UPE_RegisterPropertyFloat("health", 1.0, "Health boost");
	UPE_RegisterPropertyFloat("speed", 1.0, "Speed boost");
	UPE_RegisterPropertyFloat("gravity", 1.0, "Gravity boost");
	
	decl String:folderName[32];
	GetGameFolderName(folderName, sizeof(folderName));
	
	if(StrEqual(folderName, "tf"))
		tf = true;
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsClientInGame(client))
		return Plugin_Continue;
		
	if (!IsPlayerAlive(client))
		return Plugin_Continue;
		
	if (!UPE_IsClientPremium(client))
		return Plugin_Continue;
	
	SetEntityHealth(client, RoundToNearest(float(GetEntProp(client, Prop_Data, "m_iMaxHealth")) * UPE_GetClientPropertyFloat(client, "health")));
	SetEntityGravity(client, UPE_GetClientPropertyFloat(client, "gravity"));
	
	return Plugin_Continue;
}

public OnGameFrame()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (!IsPlayerAlive(client))
			continue;
			
		if (!UPE_IsClientPremium(client))
			continue;
		
		new Float:normalSpeed = 300.0;
		new bool:isCharging = false;
		
		if (tf)
		{
			normalSpeed = g_basespeed[TF2_GetPlayerClass(client)];
			isCharging = TF2_IsPlayerInCondition(client, TFCond_Charging);
		}
		
		if (!isCharging)
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", normalSpeed * UPE_GetClientPropertyFloat(client, "speed"));
	}
}