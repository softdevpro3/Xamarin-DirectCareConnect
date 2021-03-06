USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_ClientsAddSpecialRate]    Script Date: 9/16/2019 4:23:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_ClientsAddSpecialRate]
@userprId INTEGER,
@userLevel VARCHAR(100),
@spRtId INTEGER,
@clsvId INTEGER,
@clsvidId INTEGER,
@ratio DECIMAL(2,1),
@rate DECIMAL(6, 2) 


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
			IF @spRtId = 0
				INSERT INTO ClientSpecialRates(clsvId,clsvidId,ratio,rate)VALUES(
				@clsvId,@clsvidId,@ratio,@rate);
			ELSE
			UPDATE ClientSpecialRates SET clsvId=@clsvId,clsvidId=@clsvidId,ratio=@ratio,rate=@rate
			WHERE spRtId=@spRtId
			/* 0- Client Services */
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

			/* 1  Client Auth Info */
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

			/* 2- Special Rates */
			SELECT DISTINCT SPR.* 
			FROM ClientSpecialRates AS SPR 
			WHERE SPR.clsvId=@clsvId;

	END
END