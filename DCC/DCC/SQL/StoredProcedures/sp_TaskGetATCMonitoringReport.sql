USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_TaskGetATCMonitoringReport]    Script Date: 9/30/2019 11:13:20 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_TaskGetATCMonitoringReport]
@userprId INTEGER,
@userLevel VARCHAR(100),
@clsvId INTEGER,
@ATCMonitorId INTEGER

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
			SELECT C.fn+' '+C.ln AS cnm,AM.*
			FROM CLientATCMonitoring AS AM
			JOIN THPLCl AS C ON C.clsvId=AM.clsvId
			WHERE AM.ATCMonitorId=@ATCMonitorId
			/*
			SELECT CAM.*, AQ.qNum,AQ.question
			FROM ClientATCMonitoringQuestions AS CAM
			JOIN ATCQuestions AS AQ ON AQ.atcquestId=CAM.atcQuestId
			WHERE ATCMonitorId=@ATCMonitorId
			ORDER BY AQ.qNum ASC
			*/

			
			SELECT CAM.*, AQ.qNum,AQ.question
			FROM ATCQuestions AS AQ
			LEFT JOIN ClientATCMonitoringQuestions AS CAM ON CAM.atcquestId=AQ.atcQuestId			
			WHERE AQ.deleted=0
			ORDER BY AQ.qNum ASC

		END
END