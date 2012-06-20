#pragma semicolon 1

#include <sourcemod>
#include <upe>

public OnPluginStart()
{
	UPE_RegisterPropertyCell("reservedslot", 1, "Reserved Slot");
}

public OnClientPostAdminFilter(client)
{
	if (!UPE_IsClientPremium(client))
		return;
		
	if (!UPE_GetClientPropertyCell(client, "reservedslot"))
		return;
		
	new clientFlags = 0;
	clientFlags = GetUserFlagBits(client);
	clientFlags|= ADMFLAG_RESERVATION;
	
	SetUserFlagBits(client, clientFlags);
}