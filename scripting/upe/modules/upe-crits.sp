// http://forums.alliedmods.net/showthread.php?t=69743

#include <sourcemod>
#include <tf2>
#include <upe>

public OnPluginStart()
{
	UPE_RegisterPropertyFloat("crits-chance", -1.0, "Modifies the chance of getting a critical hit.");
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (!UPE_IsClientPremium(client))
		return Plugin_Continue;
	
	new chance = UPE_GetClientPropertyFloat(client, "crits-chance");
	
	if (chance == -1.0)
		return Plugin_Continue;
	
	if (chance > GetRandomFloat(0.0, 1.0))
	{
		result = true;
		return Plugin_Handled;	
	}
	
	result = false;
	return Plugin_Handled;
}