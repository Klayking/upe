#pragma semicolon 1

#include <sourcemod>
#include <upe>

/** 
 * Global Enums
 */

enum Premium
{
	PremiumId,
	String:PremiumAuth[32],
	PremiumStartTime,
	PremiumEndTime,
	PremiumLevel
	// PremiumTypes:PremiumType
};

enum Level
{
	LevelId,
	String:LevelName[32],
	Handle:LevelProperties
};

enum PropertyTypes
{
	Cell,
	Float,
	String
};

enum Property
{
	String:PropertyName[32],
	String:PropertyDescription[128],
	PropertyTypes:PropertyType,
	PropertySize,
	any:PropertyDefaultValue
};

/**
 * Global Variables
 */
new reconnectcounter = 0;
new Handle:g_hSQL = INVALID_HANDLE;

new premiums[1024][Premium];
new premiumCount = 0;

new levels[32][Level];
new levelCount = 0;

new properties[128][Property];
new propertyCount = 0;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("UPE_IsClientPremium", Native_IsClientPremium);
	CreateNative("UPE_SetClientPremium", Native_SetClientPremium);
	CreateNative("UPE_FindPremiumBySteamId", Native_FindPremiumBySteamId);
	CreateNative("UPE_GetClientLevel", Native_GetClientLevel);
	
	CreateNative("UPE_RegisterPropertyCell", Native_RegisterPropertyCell);
	CreateNative("UPE_RegisterPropertyFloat", Native_RegisterPropertyFloat);
	CreateNative("UPE_RegisterPropertyString", Native_RegisterPropertyString);
	
	CreateNative("UPE_GetLevelPropertyCell", Native_GetLevelPropertyCell);
	CreateNative("UPE_GetLevelPropertyFloat", Native_GetLevelPropertyFloat);
	CreateNative("UPE_GetLevelPropertyString", Native_GetLevelPropertyString);
	
	CreateNative("UPE_GetClientPropertyCell", Native_GetClientPropertyCell);
	CreateNative("UPE_GetClientPropertyFloat", Native_GetClientPropertyFloat);
	CreateNative("UPE_GetClientPropertyString", Native_GetClientPropertyString);
	
	RegPluginLibrary("upe");
	
	return APLRes_Success;	
}

public OnPluginStart() 
{
	ConnectSQL();
}

public OnMapStart()
{
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
	else
	{
		LoadLevels();
		RefreshCache();
	}
}

ConnectSQL()
{
	if (g_hSQL != INVALID_HANDLE)
		CloseHandle(g_hSQL);
	
	g_hSQL = INVALID_HANDLE;

	if (SQL_CheckConfig("upe"))
		SQL_TConnect(ConnectSQLCallback, "upe");
	else
		PrintToServer("No config entry found for 'upe' in databases.cfg");
}

public ConnectSQLCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (reconnectcounter >= 5)
	{
		LogError("PLUGIN STOPPED - reconnect counter reached max - PLUGIN STOPPED");
		return -1;
	}

	if (hndl == INVALID_HANDLE)
	{
		LogError("Connection to SQL database has failed, Reason: %s", error);
		reconnectcounter++;
		ConnectSQL();

		return -1;
	}

	new String:driver[16];
	SQL_GetDriverIdent(owner, driver, sizeof(driver));
	
	if (StrEqual(driver, "mysql", false))
		SQL_FastQuery(hndl, "SET NAMES 'utf8'");

	g_hSQL = CloneHandle(hndl);
	
	LoadLevels();
	RefreshCache();
	
	reconnectcounter = 1;
	return 1;
}

RefreshCache()
{
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
	else
	{
		SQL_TQuery(g_hSQL, 
			RefreshCacheCallback, 
			"SELECT id, auth, UNIX_TIMESTAMP(startTime), UNIX_TIMESTAMP(endTime), level, type FROM premium WHERE isActive = 1 AND now() >= startTime AND (endTime IS NULL || now() < endTime)", 
			_, 
			DBPrio_Normal);
	}
}

public RefreshCacheCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (owner == INVALID_HANDLE)
	{
		reconnectcounter++;
		ConnectSQL();

		return -1;
	}

	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("Failed to query (error: %s)", error);
		return -1;
	}
	
	premiumCount = 0;
	
	while (SQL_FetchRow(hndl)) 
	{
		premiums[premiumCount][PremiumId] = SQL_FetchInt(hndl, 0);
		SQL_FetchString(hndl, 1, premiums[premiumCount][PremiumAuth], 32);
		premiums[premiumCount][PremiumStartTime] = SQL_FetchInt(hndl, 2);
		premiums[premiumCount][PremiumEndTime] = SQL_FetchInt(hndl, 3);
		premiums[premiumCount][PremiumLevel] = SQL_FetchInt(hndl, 4);
		
		decl String:type[10];
		SQL_FetchString(hndl, 5, type, sizeof(type));

		/*
		if (StrEqual(type, "Premium"))
			premiums[premiumCount][PremiumType] = PremiumType_Premium;
		else if (StrEqual(type, "Trial"))
			premiums[premiumCount][PremiumType] = PremiumType_Trial;
		*/
		
		premiumCount++;
	}
	
	return 1;
}

LoadLevels()
{
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/premium/levels.cfg");
	
	new Handle:kv = CreateKeyValues("premium-levels");
	FileToKeyValues(kv, path);

	levelCount = 0;
	
	if (!KvGotoFirstSubKey(kv))
		return;
	
	do
	{
		KvGetSectionName(kv, levels[levelCount][LevelName], 32);
		levels[levelCount][LevelId] = KvGetNum(kv, "level");
		
		levels[levelCount][LevelProperties] = CreateTrie();
		
		for (new property = 0; property < propertyCount; property++)
		{
			decl String:propertyName[32];
			strcopy(propertyName, sizeof(propertyName), properties[property][PropertyName]);
			
			if (properties[property][PropertyType] == Cell)
			{
				SetTrieValue(levels[levelCount][LevelProperties], 
					propertyName, 
					KvGetNum(kv, propertyName, properties[property][PropertyDefaultValue]));
			}
			else if (properties[property][PropertyType] == Float)
			{
				SetTrieValue(levels[levelCount][LevelProperties], 
					propertyName, 
					KvGetFloat(kv, propertyName, properties[property][PropertyDefaultValue]));
			}
			else if (properties[property][PropertyType] == String)
			{
				decl String:value[properties[property][PropertySize]];
				
				KvGetString(
					kv, 
					propertyName, 
					value, 
					properties[property][PropertySize], 
					properties[property][PropertyDefaultValue]);
				
				SetTrieString(levels[levelCount][LevelProperties], propertyName, value);
			}
		}
		
		levelCount++;
	} while (KvGotoNextKey(kv));
	
	CloseHandle(kv);		
}

bool:IsClientPremium(client)
{
	decl String:auth[32];
	GetClientAuthString(client, auth, sizeof(auth));
	
	return (FindPremiumBySteamId(auth) != -1);
}

FindPremiumBySteamId(const String:auth[])
{
	for (new premium = 0; premium < premiumCount; premium++)
	{
		if (StrEqual(auth, premiums[premium][PremiumAuth]))
			return premium;
	}
	
	return -1;
}

FindLevelIndexById(level)
{
	for (new levelIndex = 0; levelIndex < levelCount; levelIndex++)
	{
		if (levels[levelIndex][LevelId] == level)
			return levelIndex;
	}
	
	return -1;
}

GetClientLevel(client)
{
	decl String:auth[32];
	GetClientAuthString(client, auth, sizeof(auth));
	
	new premium = FindPremiumBySteamId(auth);
	
	if (premium != -1)
		return premiums[premium][PremiumLevel];
	
	return -1;
}

GetLevelPropertyCell(level, const String:propertyName[])
{
	new levelIndex = FindLevelIndexById(level);
	
	if (levelIndex == -1)
		return -1;
		
	new value;
	GetTrieValue(levels[levelIndex][LevelProperties], propertyName, value);
	
	return value;	
}

Float:GetLevelPropertyFloat(level, const String:propertyName[])
{	
	new levelIndex = FindLevelIndexById(level);
	
	if (levelIndex == -1)
		return -1.0;
		
	new Float:value;
	GetTrieValue(levels[levelIndex][LevelProperties], propertyName, value);
	
	return value;	
}

bool:GetLevelPropertyString(level, const String:propertyName[], String:value[])
{
	new levelIndex = FindLevelIndexById(level);
	
	if (levelIndex == -1)
		return false;
		
	return GetTrieString(levels[levelIndex][LevelProperties], propertyName, value, GetPropertySize(propertyName));
}

GetPropertySize(const String:propertyName[], defaultValue = 32)
{
	for (new property = 0; property < propertyCount; property++)
	{
		if (StrEqual(propertyName, properties[property][PropertyName]))
			return properties[property][PropertySize];
	}
	
	return defaultValue;
}

public Native_IsClientPremium(Handle:plugin, params)
{
	return IsClientPremium(GetNativeCell(1));
}

public Native_SetClientPremium(Handle:plugin, params)
{
	return IsClientPremium(GetNativeCell(1));
}

public Native_FindPremiumBySteamId(Handle:plugin, params)
{
	new String:auth[64];
	GetNativeString(1, auth, sizeof(auth));
	
	return FindPremiumBySteamId(auth);
}

public Native_GetClientLevel(Handle:plugin, params)
{
	return GetClientLevel(GetNativeCell(1));
}

public Native_RegisterPropertyCell(Handle:plugin, params)
{
	if (propertyCount >= sizeof(properties))
		return false;
	
	new property = 0;
	
	for (; property < sizeof(properties); property++)
	{
		if (StrEqual(properties[property][PropertyName], properties[propertyCount][PropertyName]))
			break;
	}
	
	GetNativeString(1, properties[property][PropertyName], 32);
	properties[property][PropertyDefaultValue] = GetNativeCell(2);
	GetNativeString(3, properties[property][PropertyDescription], 128);
	properties[property][PropertyType] = Cell;
	
	if (property == propertyCount)
		propertyCount++;
	
	return true;
}

public Native_RegisterPropertyFloat(Handle:plugin, params)
{
	if (propertyCount >= sizeof(properties))
		return false;

	new property = 0;
	
	for (; property < sizeof(properties); property++)
	{
		if (StrEqual(properties[property][PropertyName], properties[propertyCount][PropertyName]))
			break;
	}
	
	GetNativeString(1, properties[property][PropertyName], 32);
	properties[property][PropertyDefaultValue] = Float:GetNativeCell(2);
	GetNativeString(3, properties[property][PropertyDescription], 128);
	properties[property][PropertyType] = Float;
	
	if (property == propertyCount)
		propertyCount++;
		
	return true;
}

public Native_RegisterPropertyString(Handle:plugin, params)
{
	if (propertyCount >= sizeof(properties))
		return false;
	
	new property = 0;
	
	for (; property < sizeof(properties); property++)
	{
		if (StrEqual(properties[property][PropertyName], properties[propertyCount][PropertyName]))
			break;
	}
	
	GetNativeString(1, properties[property][PropertyName], 32);
	GetNativeString(3, properties[property][PropertyDescription], 128);

	properties[property][PropertySize] = GetNativeCell(4);
	GetNativeString(2, properties[property][PropertyDefaultValue], properties[property][PropertySize]);
	
	properties[property][PropertyType] = String;
	
	if (property == propertyCount)
		propertyCount++;
		
	return true;
}

public Native_GetLevelPropertyCell(Handle:plugin, params)
{
	decl String:propertyName[32];
	GetNativeString(2, propertyName, sizeof(propertyName));

	return GetLevelPropertyCell(GetNativeCell(1), propertyName);
}
	
public Native_GetLevelPropertyFloat(Handle:plugin, params)
{
	decl String:propertyName[32];
	GetNativeString(2, propertyName, sizeof(propertyName));

	return _:GetLevelPropertyFloat(GetNativeCell(1), propertyName);
}

public Native_GetLevelPropertyString(Handle:plugin, params)
{
	decl String:propertyName[32];
	GetNativeString(2, propertyName, sizeof(propertyName));
	
	new size = GetPropertySize(propertyName);
	new String:value[size];
	
	new bool:success = GetLevelPropertyString(GetNativeCell(1), propertyName, value);
	SetNativeString(3, value, size);
	
	return success;
}

public Native_GetClientPropertyCell(Handle:plugin, params)
{
	decl String:propertyName[32];
	GetNativeString(2, propertyName, sizeof(propertyName));
	
	return GetLevelPropertyCell(GetClientLevel(GetNativeCell(1)), propertyName);
}

public Native_GetClientPropertyFloat(Handle:plugin, params)
{
	decl String:propertyName[32];
	GetNativeString(2, propertyName, sizeof(propertyName));
	
	return _:GetLevelPropertyFloat(GetClientLevel(GetNativeCell(1)), propertyName);
}

public Native_GetClientPropertyString(Handle:plugin, params)
{
	decl String:propertyName[32];
	GetNativeString(2, propertyName, sizeof(propertyName));
	
	new size = GetPropertySize(propertyName);
	new String:value[size];
	
	new bool:success = GetLevelPropertyString(GetClientLevel(GetNativeCell(1)), propertyName, value);
	SetNativeString(3, value, size);
	
	return success;
}