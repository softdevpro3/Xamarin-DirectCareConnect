USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_TaskGetHAHNote]    Script Date: 9/24/2019 10:50:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_TaskGetHAHNote]
@userprId INTEGER,
@userLevel VARCHAR(100),
@clsvId INTEGER,
@clHAHNoteId INTEGER

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
			SELECT C.fn+ ' ' +c.ln AS cnm,CN.*
			FROM CLientNotesHAH AS CN
			JOIN THPLcl AS C ON C.clsvId=CN.clsvId

			SELECT CNL.*,CNO.note,CNO.score 
			FROM CLientNotesHAH AS CN
			JOIN THPLcl AS C ON C.clsvId=CN.clsvId
			LEFT JOIN ClientHAHObjectiveList AS CNL ON CNL.clsvidId=CN.clsvidId AND CNL.deleted=0
			LEFT JOIN ClientNotesHAHObjectives AS CNO ON CNO.clHaHNoteId=CN.clHahNoteId AND CNO.objectiveId=CNL.objectiveId
			WHERE CN.clHAHNoteId=@clHAHNoteId

			


		END
END