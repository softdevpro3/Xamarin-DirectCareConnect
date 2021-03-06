USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_StaffGetStaffList]    Script Date: 9/15/2019 2:47:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_StaffGetStaffList]
@userprId INTEGER,
@userLevel VARCHAR(100)
AS
BEGIN
	/* 0 - StaffList */
	IF @userLevel='SuperAdmin' OR @userLevel='HumanResources'
	BEGIN
		SELECT S.prid,S.ln+' ' + S.fn AS nm,S.deleted
		FROM THPLipr AS S
		WHERE S.deldt>DATEADD(year, -2, GETDATE()) ORDER BY nm ASC
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
		WHERE S2.prid<>0 AND S2.prID IS NOT NULL
		)
		SELECT DISTINCT nm,prId,deleted 
		FROM StaffList 
		WHERE prId<>@userprId
		ORDER BY nm ASC
	END

	/* 1 - Payroll Departments */
	SELECT prDeptId,prDeptCode 
	FROM PayrollDepts 
	WHERE deleted=0 
	ORDER BY prDeptCode ASC;

	/* 2 - Client services list */
	SELECT C.ln+' '+C.fn AS cnm,c.clsvId
    FROM THPLcl AS C
    WHERE C.deleted=0 ORDER BY ln ASC, fn ASC

	/* 3 CLientStaff Relationships */
	SELECT * FROM AtcRelationships
	ORDER BY atcRelId ASC

	/* 3 - last 12 weeks of payroll */
    SELECT TOP 12 ws, we FROM THPLwks
    WHERE GETDATE()>=ws
    ORDER BY ws DESC

	/* 4 supervisory role */
	SELECT R.roleId,R.roleName 
	FROM StaffRoles AS R
    WHERE R.isSupervisory<>0 AND R.enabled<>0;

	/* 5 list of supervisory staff */
	SELECT S.prId,S.ln + ' ' + S.fn AS nm, R.roleId,R.roleName 
	FROM THPLipr AS S
    JOIN StaffRoles AS R ON R.roleId=S.isSupervisor OR R.roleId=S.isAssistantDirector OR R.roleId=S.isDirector
    WHERE S.deleted=0


END