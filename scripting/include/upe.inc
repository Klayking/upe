#if defined _upe_included
 #endinput
#endif
#define _upe_included

#pragma semicolon 1

#define PL_VERSION "1.0.0-dev"

/**
 * Determines whether a specific client is premium.
 *
 * @param client	Player index.
 *
 * @return True if premium, false otherwise.
 */
native bool:UPE_IsClientPremium(client);

/**
 * Sets client a premium.
 *
 * @param client	Player index.
 * @param level		Level index.
 * @param startTime
 * @param endTime
 *
 * @return True on success, false otherwise.
 */
native bool:UPE_SetClientPremium(client, level, startTime, endTime);

/**  
 * Determines whether a steamid is premium.
 * 
 * @param steamId	SteamId
 *
 * @return Premium's unique identifer, or -1 if not premium.
 */
native bool:UPE_FindPremiumBySteamId(const String:steamId[]);

/**  
 * Gets client premium level.
 * 
 * @param client	Player index.
 *
 * @return Premium level, or -1 if not premium.
 */
native UPE_GetClientLevel(client);

native bool:UPE_RegisterPropertyCell(const String:propertyName[], any:defaultValue = 0, const String:description[] = "");
native bool:UPE_RegisterPropertyFloat(const String:propertyName[], Float:defaultValue = 0.0, const String:description[] = "");
native bool:UPE_RegisterPropertyString(const String:propertyName[], const String:defaultValue[] = "", const String:description[] = "", size);

native UPE_GetLevelPropertyCell(level, const String:propertyName[]);
native Float:UPE_GetLevelPropertyFloat(level, const String:propertyName[]);
native bool:UPE_GetLevelPropertyString(level, const String:propertyName[], String:value[]);

native UPE_GetClientPropertyCell(client, const String:propertyName[]);
native Float:UPE_GetClientPropertyFloat(client, const String:propertyName[]);
native bool:UPE_GetClientPropertyString(client, const String:propertyName[], String:value[]);

public SharedPlugin:__pl_upe = 
{
	name = "upe",
	file = "upe-core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_upe_SetNTVOptional()
{
	MarkNativeAsOptional("UPE_IsClientPremium");
	MarkNativeAsOptional("UPE_SetClientPremium");
	MarkNativeAsOptional("UPE_FindPremiumBySteamId");
}