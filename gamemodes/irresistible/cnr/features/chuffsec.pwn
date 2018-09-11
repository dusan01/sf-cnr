/*
 * Irresistible Gaming (c) 2018
 * Developed by Lorenc Pekaj
 * Module: cnr\features\chuffsec.pwn
 * Purpose: robbable npc security truck implementation
 */

/* ** Error checking ** */
#if !defined __cnr__chuffsec
	#define __cnr__chuffsec
#endif

/* ** Includes ** */
#include 							< YSI\y_hooks >

/* ** Definitions ** */
#define SECURE_TRUCK_DRIVER_NAME 	( "ChuffSec" )
#define SECURE_TRUCK_DISTANCE 		( 6.0 )
#define SECURE_TRUCK_RADIUS 		( 4.0 )
#define COLOR_SECURITY 				0xFF440500

#define PROGRESS_ROBTRUCK 			2

/* ** Variables ** */
enum E_SECURE_OFFSET {
	Float: E_X, 			Float: E_Y, 			Float: E_Z,
	bool: E_LEFT, 			bool: E_ENABLED, 		Float: E_HP
};

enum E_SECURE_VEHICLE {
	E_LOOT, 				bool: E_ROBBED,			bool: E_OPEN,
	bool: E_BEING_ROBBED,	E_MAP_ICON
};

new
	Float: g_secureTruckOffsets[ ] [ E_SECURE_OFFSET ] =
	{
		{ 0.6641840, -3.134811, -0.072469, false, true, 100.0 },
		{ 0.6666250, -3.096450, 1.2469670, false, true, 100.0 },
		{ -0.641235, -3.098449, 1.2477970, true , true, 100.0 },
		{ -0.637695, -3.136108, -0.079330, true , true, 100.0 }
	},
	g_secureTruckData 					[ E_SECURE_VEHICLE ],
	g_secureTruckDriver					= INVALID_PLAYER_ID,
	g_secureTruckVehicle 				= INVALID_VEHICLE_ID,
	Text3D: g_secureTruckVehicleLabel	[ sizeof( g_secureTruckOffsets ) ] = { Text3D: INVALID_3DTEXT_ID, ... }
;

/* ** Hooks ** */
hook OnScriptInit( )
{
	g_secureTruckVehicle 	= AddStaticVehicle( 428, 2000.0, 2000.0, 2000.0, 180.0, -1, -1 );

	for( new i = 0; i < sizeof( g_secureTruckOffsets ); i++ ) {
  		g_secureTruckVehicleLabel[ i ] = CreateDynamic3DTextLabel( "100%", setAlpha( COLOR_GREY, 0x90 ), g_secureTruckOffsets[ i ] [ E_X ], g_secureTruckOffsets[ i ] [ E_Y ], g_secureTruckOffsets[ i ] [ E_Z ], 25.0, INVALID_PLAYER_ID, g_secureTruckVehicle );
	}

	ConnectNPC( SECURE_TRUCK_DRIVER_NAME, "secureguard" );
	return 1;
}

hook OnPlayerUpdateEx( playerid )
{
	static
		Float: fX, Float: fY, Float: fZ;

	if ( IsPlayerConnected( g_secureTruckDriver ) )
    {
		if ( IsSecurityDriverAFK( ) )
		{
			if ( GetPlayerSurfingVehicleID( playerid ) == g_secureTruckVehicle || IsPlayerInVehicle( playerid, g_secureTruckVehicle ) ) {
				SendServerMessage( playerid, "You seemed to fly away with the security guard. You've been teleported to a spawn." );
				CallLocalFunction( "SetPlayerRandomSpawn", "d", playerid );
			}

			if ( g_secureTruckData[ E_MAP_ICON ] != 0xFFFF ) {
				SetVehicleParamsCarDoors( g_secureTruckVehicle, 0, 0, 0, 0 );
				DestroyDynamicMapIcon( g_secureTruckData[ E_MAP_ICON ] );
				g_secureTruckData[ E_MAP_ICON ] = 0xFFFF;
			}
		}
		else
		{
	    	if ( GetPlayerPos( g_secureTruckDriver, fX, fY, fZ ) ) {
				DestroyDynamicMapIcon( g_secureTruckData[ E_MAP_ICON ] ); // Should not look sketchy
				g_secureTruckData[ E_MAP_ICON ] = CreateDynamicMapIcon( fX, fY, fZ, 52, 0, -1, -1, -1, 300.0 );
	    	}
		}
    }
	return 1;
}

hook OnNpcConnect( npcid )
{
	static
		npc_name[ MAX_PLAYER_NAME ];

    GetPlayerName( npcid, npc_name, sizeof( npc_name ) );

	if ( strmatch( npc_name, SECURE_TRUCK_DRIVER_NAME ) ) {
		g_secureTruckDriver = npcid;
		g_secureTruckData[ E_MAP_ICON ] = 0xFFFF;
		SetPlayerColor( npcid, COLOR_SECURITY );
		PutPlayerInVehicle( npcid, g_secureTruckVehicle, 0 );
		return Y_HOOKS_BREAK_RETURN_1;
	}
	return Y_HOOKS_CONTINUE_RETURN_1;
}

hook OnNpcDisconnect( npcid, reason )
{
	if ( g_secureTruckDriver == npcid )
	{
		restartSecurityGuardProcess( .inform_npc = false );
		g_secureTruckDriver = INVALID_PLAYER_ID;
		print( "Driver Crashed, Restablishing." );
		ConnectNPC( SECURE_TRUCK_DRIVER_NAME, "secureguard" );
		return Y_HOOKS_BREAK_RETURN_1;
	}
	return 1;
}

hook OnPlayerText( playerid, text[ ] )
{
	if ( IsPlayerSecurityDriver( playerid ) )
	{
		if ( strmatch( text, "End Security Guard" ) )
		{
			restartSecurityGuardProcess( );
			return Y_HOOKS_BREAK_RETURN_0;
		}
		return Y_HOOKS_BREAK_RETURN_1;
	}
	return 1;
}

hook OnPlayerDriveVehicle(playerid, vehicleid)
{
	if ( IsPlayerConnected( g_secureTruckDriver ) && vehicleid == g_secureTruckVehicle ) {
		SendError( playerid, "This vehicle cannot be accessed." );
		SyncObject( playerid, 1 ); // Just sets the players position where the vehicle is.
		return Y_HOOKS_BREAK_RETURN_1;
	}
	return 1;
}

hook OnPlayerKeyStateChange( playerid, newkeys, oldkeys )
{
	new Float: X, Float: Y, Float: Z, Float: Angle;
	new player_vehicle = GetPlayerVehicleID( playerid );

	if ( PRESSED( KEY_WALK ) )
	{
		if ( CanPlayerExitEntrance( playerid ) && player_vehicle )
		{
        	new Float: fX, Float: fY;

    		UpdatePlayerEntranceExitTick( playerid );

    		GetVehiclePos( g_secureTruckVehicle, X, Y, Z );
    		GetVehicleZAngle( g_secureTruckVehicle, Angle );

		    fX = X + ( SECURE_TRUCK_DISTANCE * floatsin( -Angle + 180, degrees ) );
		    fY = Y + ( SECURE_TRUCK_DISTANCE * floatcos( -Angle + 180, degrees ) );

			if ( IsPlayerInRangeOfPoint( playerid, SECURE_TRUCK_RADIUS, fX, fY, Z ) && p_Class[ playerid ] != CLASS_POLICE )
			{
				new
					every_thing_shot = allSecurityOffsetsShot( );

				if ( every_thing_shot && g_secureTruckData[ E_OPEN ] == true  )
				{
					if ( IsSecurityDriverAFK( ) ) return 1;
					if ( g_secureTruckData[ E_BEING_ROBBED ] ) return SendError( playerid, "This truck is currently being robbed." );
					if ( g_secureTruckData[ E_ROBBED ] ) return SendError( playerid, "This truck has been robbed." );
					SetPlayerFacePoint( playerid, X, Y );
					//SetPlayerPos( playerid, fX, fY, Z );
					g_secureTruckData[ E_BEING_ROBBED ] = true;
					ApplyAnimation( playerid, "CARRY", "liftup105", 4.0, 1, 0, 0, 1, 0 );
					ShowProgressBar( playerid, "Robbing Truck", PROGRESS_ROBTRUCK, 4000, COLOR_GOLD );
				}
				return Y_HOOKS_BREAK_RETURN_1;
			}
		}
	}
	return 1;
}

/* ** Commands ** */

CMD:chuffloc( playerid, params[ ] )
{
	static
		Float: X, Float: Y, Float: Z,
		szCity[ MAX_ZONE_NAME ], szLocation[ MAX_ZONE_NAME ]
	;

	if ( IsSecurityDriverAFK( ) ) SendServerMessage( playerid, "ChuffSec is currently immobile and not making any deliveries at present." );
	else
	{
		if ( GetPlayerPos( g_secureTruckDriver, X, Y, Z ) )
		{
		  	Get2DCity( szCity, X, Y, Z );
		    GetZoneFromCoordinates( szLocation, X, Y, Z );
			SendServerMessage( playerid, "ChuffSec schedules show that the security truck is located near %s in %s.", szLocation, szCity );
		}
		else SendServerMessage( playerid, "ChuffSec is currently immobile and not making any deliveries at present." );
	}
	return 1;
}

/* ** Functions ** */

stock IsPlayerSecurityDriver( playerid ) {
	new
		npc_id = IsPlayerNPC( playerid );

	if ( strmatch( ReturnPlayerName( playerid ), SECURE_TRUCK_DRIVER_NAME ) && !npc_id ) {
		return 0;
	}

	return ( npc_id && playerid == g_secureTruckDriver );
}

stock IsVehicleSecurityVehicle( vehicleid )
{
	return vehicleid == g_secureTruckVehicle;
}

stock restartSecurityGuardProcess( bool: inform_npc = true ) {
	g_secureTruckData[ E_LOOT ] 		= 0;
	g_secureTruckData[ E_ROBBED ] 		= false;
	g_secureTruckData[ E_BEING_ROBBED ] = false;
	g_secureTruckData[ E_OPEN ] 		= false;

	DestroyDynamicMapIcon( g_secureTruckData[ E_MAP_ICON ] );
	g_secureTruckData[ E_MAP_ICON ]  	= 0xFFFF;

	for( new i = 0; i < sizeof( g_secureTruckOffsets ); i++ ) {
		g_secureTruckOffsets[ i ] [ E_LEFT ] 	= false;
		g_secureTruckOffsets[ i ] [ E_ENABLED ] = true;
		g_secureTruckOffsets[ i ] [ E_HP ] 		= 100.0;
		UpdateDynamic3DTextLabelText( g_secureTruckVehicleLabel[ i ], setAlpha( COLOR_GREY, 0x90 ), "100%" );
	}

	if ( inform_npc ) SendClientMessage( g_secureTruckDriver, 0x112233FF, "[0x03] 300 SECOND START." );
}

stock allSecurityOffsetsShot( ) {
	for( new i = 0; i < sizeof( g_secureTruckOffsets ); i++ )
		if ( g_secureTruckOffsets[ i ] [ E_ENABLED ] )
			return 0;
	return 1;
}


stock IsSecurityDriverAFK( ) { // Damn thing bugged with range of point
	new
		Float: Z;

	return ( GetPlayerPos( g_secureTruckDriver, Z, Z, Z ) && Z > 1000.0 );
}
