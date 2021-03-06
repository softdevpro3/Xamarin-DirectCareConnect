USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsAddGeoLoc]    Script Date: 9/16/2019 4:23:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsAddGeoLoc]
@userprId INTEGER,
@userLevel VARCHAR(100),
@clLocId INTEGER,
@clsvId INTEGER,
@ad1 VARCHAR(200),
@ad2 VARCHAR(100) = null,
@cty VARCHAR(100),
@st VARCHAR(2),
@zip VARCHAR(10),
@lat DECIMAL(10,7),
@lon DECIMAL(10,7),
@radius INTEGER
AS
BEGIN
	DECLARE @accessGranted AS INT = 0

	/* See if we have access to targeted staff member*/
	IF @userLevel='SuperAdmin' OR  @userLevel='HumanResources'
		SET @accessGranted = 1;
	ELSE
		WITH StaffList AS
		(SELECT S1.prid,1 AS eL
		FROM THPLipr AS S1
		WHERE prid=@userPrid
		UNION ALL
		SELECT S2.prid,SL.eL+1 AS eL
		FROM THPLipr AS S2
		INNER JOIN StaffList AS SL
		ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
		WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
		SELECT @accessGranted = COUNT(*) 
		FROM StaffList AS S 
		JOIN ClientStaffRelationships AS CSR ON CSR.prId=S.prId
		JOIN THPLcl AS C ON C.clsvId=@clsvId;

		IF @accessGranted <> 0 
		BEGIN
			IF @clLocId = 0
				INSERT INTO ClientLocations(clsvId,ad1,ad2,cty,st,zip,lat,lon,radius,active)VALUES(
				@clsvId,@ad1,@ad2,@cty,@st,@zip,@lat,@lon,@radius,1);
			ELSE
			UPDATE ClientLocations SET clsvId=@clsvId,ad1=@ad1,ad2=@ad2,cty=@cty,st=@st,zip=@zip,lat=@lat,lon=@lon,radius=@radius
			WHERE clLocId=@clLocId
			/* 0 Client Geolocations */
			SELECT CL.* FROM 
			ClientLocations AS CL
			WHERE CL.clsvId=@clsvId AND active<>0 

		END
END