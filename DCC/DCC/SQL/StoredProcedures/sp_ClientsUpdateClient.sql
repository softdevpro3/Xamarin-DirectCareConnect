USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsUpdateClient]    Script Date: 9/16/2019 4:26:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsUpdateClient]
@userprId INTEGER,
@userLevel VARCHAR(100),
@clsvId INTEGER,
@clwNm VARCHAR(150) = null,
@clwPh VARCHAR(100) = null,
@clwEm VARCHAR(150) = null,
@cid VARCHAR(20) = null,
@billRegId INTEGER
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
	UPDATE THPLcl SET clwNm=@clwNm,clwEm=@clwEm,clwPh=@clwPh,cid=@cid,billRegId=@billRegId WHERE clsvId=@clsvId;

		/* 0 client & guardians & billing region for client */
		SELECT C.clsvId,C.clID,C.fn,C.ln,C.ln+' '+C.fn As nm,C.deleted,ISNULL(C.clwNm,'')AS clwNm,ISNULL(C.clwEm,'')AS clwEm,ISNULL(C.clwPh,'')AS clwPh,B.billRegId,B.reg,B.st AS bst 
		FROM THPLcl AS C
		JOIN BillingRegions AS B ON B.billRegId=C.billRegId	
		WHERE C.clsvid=@clsvId;
	END
	

END