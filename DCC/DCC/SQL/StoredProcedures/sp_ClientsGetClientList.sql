USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsGetClientList]    Script Date: 9/16/2019 4:25:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsGetClientList]
@userprId INTEGER,
@userLevel VARCHAR(100)
AS
BEGIN
	/* 0 - StaffList */
	IF @userLevel='SuperAdmin' OR @userLevel='HumanResources'
	BEGIN
		SELECT C.clsvId,C.ln+' ' + C.fn AS nm,C.deleted
		FROM THPLcl AS C
		WHERE C.deldt>DATEADD(year, -2, GETDATE()) ORDER BY nm ASC
	END
	ELSE
	BEGIN
		WITH StaffList AS
		(SELECT S1.ln+' '+S1.fn AS nm,S1.prid,S1.deleted,1 AS eL
		FROM THPLipr AS S1
		WHERE prid=@userprId
		UNION ALL
		SELECT S2.ln+' '+S2.fn AS nm,S2.prid,S2.deleted,SL.eL+1 AS eL
		FROM THPLipr AS S2
		INNER JOIN StaffList AS SL
		ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
		WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
		SELECT DISTINCT C.ln+' '+C.fn AS nm,C.clsvid,C.deleted 
		FROM StaffList
       JOIN ClientStaffRelationships AS I ON I.prId = StaffList.prId
       JOIN THPLcl AS C ON C.clsvId=I.clsvId
       ORDER BY nm ASC;
	END

END