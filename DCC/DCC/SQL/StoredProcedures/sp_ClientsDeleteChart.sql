USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsDeleteChart]    Script Date: 10/7/2019 9:43:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsDeleteChart]
@userprId INTEGER,
@userLevel VARCHAR(100),
@clsvId INTEGER,
@chartId INTEGER

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
		/* 0 filepath */
		SELECT extension FROM ClientCharts
        WHERE chartId=@chartId;
		DELETE FROM ClientCharts
        WHERE chartId=@chartId;
		/* 1 Client Charts */
		SELECT CC.* FROM 
		ClientCharts AS CC WHERE 
		CC.clsvId=@clsvId 
		ORDER BY chartId DESC;
	END
END