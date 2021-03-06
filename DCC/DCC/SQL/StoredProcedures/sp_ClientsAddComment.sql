USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsAddComment]    Script Date: 9/16/2019 4:22:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsAddComment]
@userprId INTEGER,
@userLevel VARCHAR(100),
@clsvId INTEGER,
@comment VARCHAR(1000)
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
			INSERT INTO ClientComments(clsvid,comment,cmtdt,commentatorId)VALUES(
			@clsvId,@comment,GETDATE(),@userprId);
			/* 0 Client Comments */
			SELECT DISTINCT CC.*,C.fn + ' ' + C.ln AS subject,S.ln + ' ' + S.fn AS commentator,'Client' AS cmtType
			FROM ClientComments AS CC
			JOIN THPLcl AS C ON C.clsvid=CC.clsvid
			JOIN THPLipr AS S ON S.prId=CC.commentatorId
			WHERE CC.clsvId=@clsvId
			ORDER BY cmtDt DESC;
		END
END