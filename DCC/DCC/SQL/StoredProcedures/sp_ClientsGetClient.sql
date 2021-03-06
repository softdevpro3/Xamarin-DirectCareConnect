USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsGetClient]    Script Date: 10/7/2019 10:05:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsGetClient]
@userprId INTEGER,
@clsvId INTEGER,
@userLevel VARCHAR(100)
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
	/* 0 client & guardians & billing region for client */
	SELECT C.clsvId,C.clID,C.fn,C.ln,C.ln+' '+C.fn As nm,C.deleted,ISNULL(C.clwNm,'')AS clwNm,ISNULL(C.clwEm,'')AS clwEm,ISNULL(C.clwPh,'')AS clwPh,B.billRegId,B.reg,B.st AS bst,G.* 
	FROM THPLcl AS C
	JOIN BillingRegions AS B ON B.billRegId=C.billRegId	
	LEFT JOIN guardians AS G ON G.gId=C.gId1 OR G.gId=C.gId2 OR G.gId=C.gId3
	WHERE C.clsvid=@clsvId;

	/* 1- Client Services */
	SELECT DISTINCT CS.*,D.deptId,D.deptCode,SV.isHourly,SV.hasMaxHours,SV.hasIncNut,SV.allowSpecialRates,SV.selectrate,SV.hasWeeklySchedule,SVRA.svce,SVRADT.rate 
	FROM THPLcl AS C
	JOIN THPLclsv AS CS ON CS.clsvId=C.clsvId
	JOIN THPLloc AS CL ON CL.locId=CS.locId
	JOIN Departments AS D ON D.deptId=CL.deptId
	JOIN svco AS SV ON SV.svc=CS.svc
	LEFT JOIN svra AS SVRA ON SVRA.svId=SV.svId AND SVRA.rid=CS.rid
	LEFT JOIN svradt AS SVRADT ON SVRADT.rId=SVRA.rId AND GETDATE()>=SVRADT.efdt AND GETDATE()<=SVRADT.fndt AND SVRADT.billRegId=C.billRegId
	WHERE C.clsvId=@clsvId
	ORDER BY svc ASC;

	/* 2- Client Auth Info */
	SELECT DISTINCT CS.id AS clsvidId,CA.auid,CA.stdt,CA.eddt,CA.au,CA.uu,CA.ru,ISNULL(X.o,0)AS o,CA.au/DATEDIFF(week,stdt,eddt)AS wk
	FROM THPLcl AS C
	JOIN THPLclsv AS CS ON CS.clsvid=C.clsvid
	JOIN THPLau AS CA ON CA.clid=C.clid AND CA.secode=CS.svc AND CA.eddt>DATEADD(MONTH, -6,GETDATE())
	LEFT JOIN
		(
		SELECT au.auid,SUM(un)AS o FROM
			(
			SELECT svc,dt,(un+ajun)AS un FROM THPLhrs WHERE clsvid=@clsvId AND(un+ajun>0)AND(pd<>1 AND pd<>3)
			UNION ALL
			SELECT svc,dt,(un+ajun)AS un FROM THPLdys WHERE clsvid=@clsvId AND(un+ajun>0)AND(pd<>1 AND pd<>3)
			UNION ALL
			SELECT svc,dt,(un+ajun)AS un FROM THPLHCBSHrsBill WHERE clsvid=@clsvId AND(un+ajun>0)AND(pd<>1 AND pd<>3)AND billASGroup IS NULL
			UNION ALL
			SELECT DISTINCT svc,dt,CAST(12 AS DECIMAL)AS un FROM THPLHCBSHrsBill WHERE clsvid=@clsvId  AND(pd<>1 AND pd<>3)AND billASGroup IS NOT NULL
			)AS A
		JOIN THPLcl AS cl ON cl.clsvid=1607
		LEFT JOIN THPLau AS au ON au.clid=cl.clid AND au.secode=A.svc AND A.dt>=au.stdt AND A.dt<=au.eddt
		GROUP BY auid)AS X ON x.auid=CA.auid
	WHERE C.clsvId=@clsvId

	/* 3- Special Rates */
	SELECT DISTINCT SPR.* 
	FROM ClientSpecialRates AS SPR 
	WHERE SPR.clsvId=@clsvId;

	/* 4 Client GeoLocations */
	SELECT DISTINCT CL.* 
	FROM ClientLocations AS CL WHERE CL.clsvId=@clsvId AND CL.active<>0;

	/* 5 Client Charts */
	SELECT CC.* FROM 
	ClientCharts AS CC WHERE 
	CC.clsvId=@clsvId 
	ORDER BY chartId DESC;

	/* 6 - Client Comments */
	SELECT DISTINCT CC.*,C.fn + ' ' + C.ln AS subject,S.ln + ' ' + S.fn AS commentator,'Client' AS cmtType
	FROM ClientComments AS CC
	JOIN THPLcl AS C ON C.clsvid=CC.clsvid
	JOIN THPLipr AS S ON S.prId=CC.commentatorId
	WHERE CC.clsvId=@clsvId
	ORDER BY cmtDt DESC;

	/* 7 Hab Goals */		
	SELECT * FROM ClientHAHObjectiveList
	WHERE clsvId=@clsvId
	ORDER BY lastDate ASC, deleted DESC

	/* 8 Care Areas */		
	SELECT * FROM ClientATCCareAreaList
	WHERE clsvId=1475 AND deleted=0




	END
	ELSE
	BEGIN
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
		SELECT TOP 0 NULL AS x;
	END



END