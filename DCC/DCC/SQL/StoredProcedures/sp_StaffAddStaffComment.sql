USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_StaffAddStaffComment]    Script Date: 9/15/2019 2:47:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_StaffAddStaffComment]
@userLevel VARCHAR(100),
@userprId INTEGER,
@prId INTEGER,
@comment VARCHAR(500)
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
		INSERT INTO StaffComments(prId,comment,cmtdt,commentatorId)VALUES(@prId,@comment,GETDATE(),@userprId)
		/* 0 Comment History */			
		SELECT CO.*,S.fn+' '+S.ln AS commentator
		FROM StaffComments AS CO
		JOIN THPLipr AS S ON S.prId=CO.commentatorId
		WHERE CO.prId=@prId
		ORDER BY commentId DESC;
	END
	ELSE
		SELECT TOP 0 NULL AS x;

END