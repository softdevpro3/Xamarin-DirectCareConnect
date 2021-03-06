USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_StaffAddCredential]    Script Date: 9/17/2019 3:28:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_StaffAddCredential]
@userLevel VARCHAR(100),
@userprId INTEGER,
@prId INTEGER,
@credId INTEGER,
@credTypeId INTEGER,
@docId VARCHAR(30),
@validFrom DATE,
@validTo DATE

AS
BEGIN
	DECLARE @accessGranted AS INT = 0

	/* See if we have access to targeted staff member*/
	IF @userLevel='SuperAdmin' OR  @userLevel='HumanResources' OR (@userprId = @prid)
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
		SELECT @accessGranted = COUNT(*)  FROM StaffList AS I WHERE prId=@prId AND prId<>@userPrid;
	
	IF @accessGranted <> 0
	BEGIN
		IF @credId=0 
		BEGIN
		INSERT INTO StaffCredentials(prid,credTypeId,docId,validFrom,validTo,verified)VALUES(
                    @prId,@credTypeId,@docId,@validFrom,@ValidTo,0)
		 SET @credId = SCOPE_IDENTITY()	
		 SELECT @credId AS credId, '' AS fileExtension,'' AS contentType
		END
		ELSE
		BEGIN
			UPDATE StaffCredentials 
			SET prId=@prId,credTypeId=@credTypeId,docId=@docId,validFrom=@validFrom,validTo=@ValidTo
			WHERE credId=@credId
			SELECT credId, fileExtension,contentType FROM StaffCredentials WHERE credId=@credId
		END


	END
	ELSE
		SELECT TOP 0 NULL AS x;

END