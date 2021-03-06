USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_TaskGetClient]    Script Date: 9/15/2019 2:48:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_TaskGetClient]
@userLevel VARCHAR(50),
@userprId INTEGER,
@clsvId INTEGER
AS
BEGIN
DECLARE @accessGranted AS INT = 0
/* See if we have access to targeted staff member*/
IF @userLevel='SuperAdmin' OR  @userLevel='HumanResources'
	 SET @accessGranted = 1
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
	FROM StaffList AS I 
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=I.prId

/* 0 - Client Profile */
IF @accessGranted <> 0
BEGIN
	SELECT DISTINCT C.*,BR.* 
	FROM THPLcl AS C
	JOIN billingRegions AS BR ON BR.billRegId=C.billRegId
	WHERE C.clsvId=@clsvId;
END
ELSE
BEGIN
	SELECT TOP 0 NULL AS x;
END

/* 1 CLIENT ALERTS Overbilling and expiring authorizations */
If @userLevel='SuperAdmin' OR @userLevel='HumanResources'
BEGIN
	/* Get Overbilling */
	SELECT  X.clsvId,C.fn AS cfn,C.ln AS cln,C.clwNm, C.clwPh, C.clwEm,
	C.fn + ' ' + C.ln + ' ' + X.svc + ' ' + CAST(X.OverbillingAlertPct AS varchar(10)) + '% overbilling ' AS msg,
	1 AS priority
	FROM
		(
		SELECT H.clsvId,H.svc,W.ws,W.we,SR.OverbillingAlertPct,SUM(un)AS un
		FROM StaffRoles AS SR
		JOIN THPLwks AS W ON W.ws<=DATEADD(WEEK,-1, GETDATE()) AND W.we>=DATEADD(WEEK, -1, GETDATE())
		JOIN THPLHCBShrsclient AS H ON dt>=W.ws AND dt<=W.we
		WHERE SR.rolenominal=@userLevel AND SR.OverbillingAlertOn<>0
		GROUP BY H.clsvId,H.svc,W.ws,W.we,SR.OverbillingAlertPct
		) AS X
	JOIN THPLcl AS C ON C.clsvid=X.clsvId
	LEFT JOIN THPLau AS AU ON AU.clId=C.clId AND AU.secode=X.svc AND ((AU.stdt<=X.ws AND AU.eddt>=X.ws) OR (AU.stdt<=X.we AND AU.eddt>=X.we))
	WHERE un>CONVERT(DECIMAL(6,2),au/ nullif((DATEDIFF (Week , AU.stdt , AU.eddt )),0))*((100.0+X.OverbillingAlertPct)/100)
	/* Get Expiring Authorizations */
	UNION
	SELECT X.clsvId,X.cfn,X.cln,X.clwNm,X.clwPh,X.clwEm,
	X.cfn + ' ' + X.cln + ' Expiring ' + X.svc + ' authorization '+ CONVERT(varchar(11),X.eddt,101) AS msg,
	CASE
		WHEN X.AuthRedAlertOn<>0 AND DATEADD(DAY,X.AuthRedAlertDays,eddt)<GETDate() THEN 1
		WHEN X.AuthAmberAlertOn<>0 AND DATEADD(DAY,X.AuthAmberAlertDays,eddt)<GETDate() THEN 2
	END AS Priority
		FROM
		(
		SELECT C.clsvId,C.fn AS cfn,C.ln AS cln,C.clwNm,C.ClwEm,C.ClwPh,CS.svc,A.eddt,
		SR.AuthRedAlertOn,SR.AuthRedAlertDays,
		SR.AuthAmberAlertOn,SR.AuthAmberAlertDays,
		ROW_NUMBER() OVER(PARTITION BY CS.id ORDER BY eddt DESC) AS Row
		FROM StaffRoles AS SR
		JOIN THPLcl AS C ON C.deleted=0
		JOIN THPLclsv AS CS ON CS.clsvId=C.clsvId AND CS.deleted=0
		JOIN THPLau AS A ON A.clid=C.clId AND A.secode=CS.svc
		WHERE SR.rolenominal=@userLevel AND(SR.AuthAmberAlertOn<>0 OR AuthRedAlertOn<>0)
		) AS X
	WHERE Row=1 AND ((X.AuthAmberAlertOn<>0 AND DATEADD(DAY,X.AuthAmberAlertDays,eddt)<GETDate())OR(X.AuthRedAlertOn<>0 AND DATEADD(DAY,X.AuthRedAlertDays,eddt)<GETDate()))

END;
ELSE
BEGIN
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
	SELECT  X.clsvId,C.fn AS cfn,C.ln AS cln,C.clwNm,C.clwPh,C.clwEm,
	C.fn + ' ' + C.ln + ' ' + X.svc + ' ' + CAST(X.OverbillingAlertPct AS varchar(10)) + '% overbilling ' AS msg,
	1 As priority
	FROM
		(
		SELECT H.clsvId,H.svc,W.ws,W.we,SR.OverbillingAlertPct,SUM(un)AS un
		FROM StaffList AS I
		JOIN ClientStaffRelationships AS CSR ON CSR.prId=I.prId
		JOIN StaffRoles AS SR ON SR.rolenominal='Director' AND SR.OverbillingAlertOn<>0
		JOIN THPLwks AS W ON W.ws<=DATEADD(WEEK,-1, GETDATE()) AND W.we>=DATEADD(WEEK, -1, GETDATE())
		JOIN THPLHCBShrsclient AS H ON H.clsvId=CSR.clsvID AND dt>=W.ws AND dt<=W.we		
		GROUP BY H.clsvId,H.svc,W.ws,W.we,SR.OverbillingAlertPct
		) AS X
	JOIN THPLcl AS C ON C.clsvid=X.clsvId
	LEFT JOIN THPLau AS AU ON AU.clId=C.clId AND AU.secode=X.svc AND ((AU.stdt<=X.ws AND AU.eddt>=X.ws) OR (AU.stdt<=X.we AND AU.eddt>=X.we))
	WHERE un>CONVERT(DECIMAL(6,2),au/ nullif((DATEDIFF (Week , AU.stdt , AU.eddt )),0))*((100.0+X.OverbillingAlertPct)/100)
	UNION
	SELECT X.clsvId,X.cfn,X.cln,X.clwNm,X.clwPh,X.clwEm,
	X.cfn + ' ' + X.cln + ' Expiring ' + X.svc + ' authorization '+ CONVERT(varchar(11),X.eddt,101) AS msg,
	CASE
		WHEN X.AuthRedAlertOn<>0 AND DATEADD(DAY,X.AuthRedAlertDays,eddt)<GETDate() THEN 1
		WHEN X.AuthAmberAlertOn<>0 AND DATEADD(DAY,X.AuthAmberAlertDays,eddt)<GETDate() THEN 2
	END AS Priority
		FROM
		(
		SELECT C.clsvId,C.fn AS cfn,C.ln AS cln,C.clwNm,C.ClwEm,C.ClwPh,CS.svc,A.eddt,
		SR.AuthRedAlertOn,SR.AuthRedAlertDays,
		SR.AuthAmberAlertOn,SR.AuthAmberAlertDays,
		ROW_NUMBER() OVER(PARTITION BY CS.id ORDER BY eddt DESC) AS Row
		FROM StaffList
		JOIN ClientStaffRelationships AS RS ON RS.prId=StaffList.prId
		JOIN THPLcl AS C ON C.clsvid=RS.clsvId AND C.deleted=0
		JOIN THPLclsv AS CS ON CS.clsvId=C.clsvId AND CS.deleted=0
		JOIN THPLau AS A ON A.clid=C.clId AND A.secode=CS.svc
		JOIN StaffRoles AS SR ON SR.rolenominal=@userLevel AND(SR.AuthAmberAlertOn<>0 OR AuthRedAlertOn<>0)
		) AS X
	WHERE Row=1 AND ((X.AuthAmberAlertOn<>0 AND DATEADD(DAY,X.AuthAmberAlertDays,eddt)<GETDate())OR(X.AuthRedAlertOn<>0 AND DATEADD(DAY,X.AuthRedAlertDays,eddt)<GETDate()))
	ORDER By priority DESC,cln ASC,cfn ASC;
END;

/* 2 STAFF ALERTS - late Notes Alert/ATC Monitoring Alerts/HAB progress Note Alerts */
If @userLevel='SuperAdmin' OR @userLevel='HumanResources'
BEGIN 
	/* Hab progress report incomplete by provider */
	SELECT S.fn AS sfn,S.ln AS sln, S.prId,	
	S.fn + ' ' + S.ln + ' ' + CHPR.svc + ' progress report for ' + C.fn + ' ' + C.ln + ' not completed, due ' + CONVERT(varchar(11),CHPR.dueDt,101)AS msg,
	CASE 
		WHEN SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate() THEN 1
		WHEN SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate() THEN 1
	END AS priority
	FROM StaffRoles AS SR
	JOIN ClientHABProgressReport AS CHPR ON CHPR.completed=0 AND CHPR.deleted=0 AND
	((SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate())OR(SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate()))
	JOIN THPLcl AS C ON C.clsvId=CHPR.clsvId
	JOIN THPLipr AS S ON S.prId=CHPR.prId
	WHERE SR.roleNominal=@userLevel AND (SR.HabProgressReportAmberAlertOn<>0 OR SR.HabProgressReportRedAlertOn<> 0) 
	UNION
	/* Hab Progress reports not verified by supervisor */
	SELECT S.fn AS sfn,S.ln AS sln, S.prId,
	S.fn + ' ' + S.ln + ' ' + CHPR.svc + ' progress report for ' + C.fn + ' ' + C.ln + ' not verified, due ' + CONVERT(varchar(11),CHPR.dueDt,101)AS msg,
	CASE 
		WHEN SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate() THEN 1
		WHEN SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate() THEN 1
	END AS priority
	FROM StaffRoles AS SR
	JOIN ClientHABProgressReport AS CHPR ON CHPR.completed<>0 AND CHPR.verified=0 AND CHPR.deleted=0 AND
	((SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate())OR(SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate()))
	JOIN THPLcl AS C ON C.clsvId=CHPR.clsvId
	JOIN THPLipr AS I ON I.prId=CHPR.prId
	JOIN THPLipr AS S ON S.prid=I.supPrId OR S.prId=I.tempsupPrid /* Gets supervisors */
	WHERE SR.roleNominal=@userLevel AND (SR.HabProgressReportAmberAlertOn<>0 OR SR.HabProgressReportRedAlertOn<> 0)
	UNION
	/* ATC Monitoring Reports */
	SELECT S.fn AS sfn,S.ln AS sln, S.prId,
	S.fn + ' ' + S.ln + ' ' + CAM.svc + ' monitoring for ' + C.fn + ' ' + C.ln + '  due ' + CONVERT(varchar(11),CAM.dueDt,101),
	CASE 
		WHEN SR.ATCMonitoringRedAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringRedAlertDays,dueDt)<GETDate() THEN 1
		WHEN SR.ATCMonitoringAmberAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringAmberAlertDays,dueDt)<GETDate() THEN 1
	END AS priority
	FROM StaffRoles AS SR
	JOIN ClientATCMonitoring AS CAM ON CAM.completed=0 AND CAM.deleted=0 AND
	((SR.ATCMonitoringAmberAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringAmberAlertDays,dueDt)<GETDate())OR(SR.ATCMonitoringRedAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringRedAlertDays,dueDt)<GETDate()))
	JOIN THPLcl AS C ON C.clsvId=CAM.clsvId
	JOIN ClientStaffRelationships AS CSR ON CSR.clsvId=CAM.clsvId
	JOIN THPLipr AS I ON I.prId=CSR.prId
	JOIN THPLipr AS S ON S.prid=I.supPrId OR S.prId=I.tempsupPrid
	WHERE SR.roleNominal='SuperAdmin' AND (SR.ATCMonitoringAmberAlertOn<>0 OR SR.ATCMonitoringRedAlertOn<> 0) 
	UNION
	/* Credentials */
	SELECT TOP 50 X.fn AS sfn,X.ln AS sln,X.prId,
	CASE
		WHEN validTo IS NULL THEN X.fn + ' ' + X.ln + ' Missing ' + X.credName
		WHEN verified=0 THEN X.fn + ' ' + X.ln + ' Requires Verification for ' + X.credName
		WHEN (SR.CredRedAlertOn<>0 AND DATEADD(DAY,SR.credRedAlertDays,validTo)<GETDate())OR(SR.CredAmberAlertOn<>0 AND DATEADD(DAY,SR.credAmberAlertDays,validTo)<GETDate()) THEN X.fn + ' ' + X.ln +  'Expiring ' + X.credName + ' '  +CONVERT(VARCHAR(11), validTo, 101)
	END AS msg,
	CASE
		WHEN validTo IS NULL THEN 1
		WHEN verified=0 THEN 1
		WHEN SR.CredRedAlertOn<>0 AND DATEADD(DAY,SR.credRedAlertDays,validTo)<GETDate() THEN 1
		WHEN SR.CredAmberAlertOn<>0 AND DATEADD(DAY,SR.credAmberAlertDays,validTo)<GETDate() THEN 2
	END AS priority
	FROM
		(
		SELECT DISTINCT S2.prId,S2.fn,S2.ln,ICI.credName,ICI.credTypeId,IC.credId,IC.verified,IC.validFrom,IC.validTo,IC.docId,IC.verificationDate,S.fn+' '+S.ln AS verifier,
		ROW_NUMBER() OVER(PARTITION BY S2.prId,ICI.credTypeId ORDER BY IC.verified ASC,IC.validTo DESC)AS R
		FROM THPLipr AS S2
		JOIN CredentialIds AS ICI ON(S2.isSuperAdmin<>0 AND ICI.superadmin<>0)OR(S2.isHumanResources<>0 AND ICI.humanResources<>0)OR(S2.isDirector<>0 AND ICI.director<>0)OR(S2.isAssistantDirector<>0 AND ICI.assistantdirector<>0)OR(S2.isSupervisor<>0 AND ICI.supervisor<>0)OR(S2.isProvider<>0 AND ICI.provider<>0)OR(S2.profLicReq<>0 AND ICI.credTypeId=7)OR(S2.profLiabilityReq<>0 AND ICI.credTypeId=8)OR(S2.providesTransport='Y' AND ICI.credTypeId=9)OR(S2.ownVehicle='Y' AND(ICI.credTypeId=10 OR ICI.credTypeId=11))
		LEFT JOIN StaffCredentials AS IC ON IC.prId=S2.prId AND IC.credTypeId=ICI.credTypeId
		LEFT JOIN THPLipr AS S ON S.prid=IC.verifier
		WHERE S2.deleted=0
		)AS X
	JOIN StaffRoles AS SR ON SR.rolenominal=@userLevel
	WHERE R=1 AND((SR.CredAmberAlertOn<>0 AND (validTo IS NULL OR verified=0 OR DATEADD(DAY,SR.CredAmberAlertDays,validTo)<GETDate()))OR(SR.CredRedAlertOn<>0 AND (validTo IS NULL OR verified=0 OR DATEADD(DAY,SR.CredRedAlertDays,validTo)<GETDate())))	
END;
ELSE
BEGIN
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
/* late note alerts */
SELECT S.fn AS sfn, S.ln AS sln, N.prId,
CASE 
  WHEN N.lostSession<> 0 THEN S.fn + ' ' + S.ln + ' ' + noteType + ' Client Note for ' + C.fn + ' ' + C.ln + ' Incomplete - Session Lost'
  ELSE S.fn + ' ' + S.ln + ' ' + noteType + ' Client Note for ' + C.fn + ' ' + C.ln + ' Incomplete'
END AS msg,
1 AS priority
FROM 
	(
	SELECT CN.prId,CN.clsvId,CN.svc,CN.clRspNoteId AS NtId,CN.Completed,CN.deleted,CN.lostSession,'RSP' AS noteType FROM staffList AS I
	JOIN ClientNotesRSP AS CN ON CN.prId=I.prId
	WHERE completed=0 OR lostSession<>0 AND deleted=0
	UNION
	SELECT CN.prId,CN.clsvId,CN.svc,CN.clAtcNoteId AS NtId,CN.Completed,CN.deleted,CN.lostSession,'ATC' AS noteType  FROM staffList AS I
	JOIN ClientNotesATC AS CN ON CN.prId=I.prId
	WHERE completed=0 OR lostSession<>0 AND deleted=0
	UNION
	SELECT CN.prId,CN.clsvId,CN.svc,CN.clHahNoteId AS NtId,CN.Completed,CN.deleted,CN.lostSession,'HAH' AS noteType  FROM staffList AS I
	JOIN ClientNotesHAH AS CN ON CN.prId=I.prId
	WHERE completed=0 OR lostSession<>0 AND deleted=0
	) AS N
JOIN THPLcl AS C ON C.clsvId=N.clsvId
JOIN THPLipr AS S ON S.prId=N.prId
WHERE ((@userlevel = 'Provider' OR @userlevel = 'Supervisor') AND N.completed = 0 AND N.deleted=0) OR
(N.lostSession<>0 AND N.deleted=0)
UNION
	/* ATC/HSK monitoring reports */
	SELECT S.fn AS sfn,S.ln AS sln, S.prId,
	S.fn + ' ' + S.ln + ' ' + CAM.svc + ' monitoring for ' + C.fn + ' ' + C.ln + '  due ' + CONVERT(varchar(11),CAM.dueDt,101),
	CASE 
		WHEN SR.ATCMonitoringRedAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringRedAlertDays,dueDt)<GETDate() THEN 1
		WHEN SR.ATCMonitoringAmberAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringAmberAlertDays,dueDt)<GETDate() THEN 1
	END AS priority
	FROM StaffList AS SL
	JOIN StaffRoles AS SR ON SR.roleNominal=@userLevel AND (SR.ATCMonitoringAmberAlertOn<>0 OR SR.ATCMonitoringRedAlertOn<> 0) 
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=SL.prId
	JOIN ClientATCMonitoring AS CAM ON CAM.clsvId=CSR.clsvId AND CAM.completed=0 AND CAM.deleted=0 AND
	((SR.ATCMonitoringAmberAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringAmberAlertDays,dueDt)<GETDate())OR(SR.ATCMonitoringRedAlertOn<>0 AND DATEADD(DAY,SR.ATCMonitoringRedAlertDays,dueDt)<GETDate()))
	JOIN THPLcl AS C ON C.clsvId=CAM.clsvId
	JOIN THPLipr AS I ON I.prId=CSR.prId
	JOIN THPLipr AS S ON S.prid=I.supPrId OR S.prId=I.tempsupPrid
	UNION
	/* Hab progress report incomplete */
	SELECT S.fn AS sfn,S.ln AS sln, S.prId,	
	S.fn + ' ' + S.ln + ' ' + CHPR.svc + ' progress report for ' + C.fn + ' ' + C.ln + ' not completed, due ' + CONVERT(varchar(11),CHPR.dueDt,101),
	CASE 
		WHEN SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate() THEN 1
		WHEN SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate() THEN 1
	END AS priority
	FROM StaffList AS SL
	JOIN StaffRoles AS SR ON SR.roleNominal=@userLevel AND (SR.HabProgressReportAmberAlertOn<>0 OR SR.HabProgressReportRedAlertOn<> 0) 
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=SL.prId
	JOIN ClientHABProgressReport AS CHPR ON CHPR.clsvId=CSR.clsvID AND CHPR.completed=0 AND CHPR.deleted=0 AND
	((SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate())OR(SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate()))
	JOIN THPLcl AS C ON C.clsvId=CHPR.clsvId
	JOIN THPLipr AS S ON S.prId=CHPR.prId
	
	UNION
	/* Hab Progress reports not verified by supervisor */
	SELECT S.fn AS sfn,S.ln AS sln, S.prId,
	S.fn + ' ' + S.ln + ' ' + CHPR.svc + ' progress report for ' + C.fn + ' ' + C.ln + ' not verified, due ' + CONVERT(varchar(11),CHPR.dueDt,101),
	CASE 
		WHEN SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate() THEN 1
		WHEN SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate() THEN 1
	END AS priority
	FROM StaffList AS SL
	JOIN StaffRoles AS SR ON SR.roleNominal=@userLevel AND (SR.HabProgressReportAmberAlertOn<>0 OR SR.HabProgressReportRedAlertOn<> 0) 
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=SL.prId
	JOIN ClientHABProgressReport AS CHPR ON CHPR.clsvId=CSR.clsvID AND CHPR.completed<>0 AND CHPR.verified=0 AND CHPR.deleted=0 AND
	((SR.HabProgressReportAmberAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportAmberAlertDays,dueDt)<GETDate())OR(SR.HabProgressReportRedAlertOn<>0 AND DATEADD(DAY,SR.HabProgressReportRedAlertDays,dueDt)<GETDate()))
	JOIN THPLcl AS C ON C.clsvId=CHPR.clsvId
	JOIN THPLipr AS I ON I.prId=CHPR.prId
	JOIN THPLipr AS S ON S.prid=I.supPrId OR S.prId=I.tempsupPrid
UNION 
/* Credential alerts */
SELECT X.fn AS sfn,X.ln AS sln,X.prId,
CASE
WHEN validTo IS NULL THEN X.fn + ' ' + X.ln + ' Missing ' + X.credName
WHEN verified=0 THEN X.fn + ' ' + X.ln + ' Requires Verification for ' + X.credName
WHEN (SR.CredRedAlertOn<>0 AND DATEADD(DAY,SR.credRedAlertDays,validTo)<GETDate())OR(SR.CredAmberAlertOn<>0 AND DATEADD(DAY,SR.credAmberAlertDays,validTo)<GETDate()) THEN X.fn + ' ' + X.ln +  'Expiring ' + X.credName + ' '  +CONVERT(VARCHAR(11), validTo, 101)
END AS msg,
CASE
	WHEN validTo IS NULL THEN 1
	WHEN verified=0 THEN 1
	WHEN SR.CredRedAlertOn<>0 AND DATEADD(DAY,SR.credRedAlertDays,validTo)<GETDate() THEN 1
	WHEN SR.CredAmberAlertOn<>0 AND DATEADD(DAY,SR.credAmberAlertDays,validTo)<GETDate() THEN 2
END AS priority
FROM
	(
	SELECT DISTINCT I.prId,S2.fn,S2.ln,ICI.credName,ICI.credTypeId,IC.credId,IC.verified,IC.validFrom,IC.validTo,IC.docId,IC.verificationDate,S.fn+' '+S.ln AS verifier,
	ROW_NUMBER() OVER(PARTITION BY I.prId,ICI.credTypeId ORDER BY IC.verified ASC,IC.validTo DESC)AS R
	FROM StaffList AS I
	JOIN THPLipr AS S2 ON S2.prId=I.prId
	JOIN CredentialIds AS ICI ON(S2.isSuperAdmin<>0 AND ICI.superadmin<>0)OR(S2.isHumanResources<>0 AND ICI.humanResources<>0)OR(S2.isDirector<>0 AND ICI.director<>0)OR(S2.isAssistantDirector<>0 AND ICI.assistantdirector<>0)OR(S2.isSupervisor<>0 AND ICI.supervisor<>0)OR(S2.isProvider<>0 AND ICI.provider<>0)OR(S2.profLicReq<>0 AND ICI.credTypeId=7)OR(S2.profLiabilityReq<>0 AND ICI.credTypeId=8)OR(S2.providesTransport='Y' AND ICI.credTypeId=9)OR(S2.ownVehicle='Y' AND(ICI.credTypeId=10 OR ICI.credTypeId=11))
	LEFT JOIN StaffCredentials AS IC ON IC.prId=I.prId AND IC.credTypeId=ICI.credTypeId
	LEFT JOIN THPLipr AS S ON S.prid=IC.verifier
	)AS X
JOIN StaffRoles AS SR ON SR.rolenominal=@userLevel
WHERE R=1 AND((SR.CredAmberAlertOn<>0 AND (validTo IS NULL OR verified=0 OR DATEADD(DAY,SR.CredAmberAlertDays,validTo)<GETDate()))OR(SR.CredRedAlertOn<>0 AND (validTo IS NULL OR verified=0 OR DATEADD(DAY,SR.CredRedAlertDays,validTo)<GETDate())))
ORDER BY priority ASC;
END;


If @accessGranted<>0
BEGIN
	/* 3- Client Services */
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

	/* 4- Client Auth Info */
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

	/* 5- Special Rates */
	SELECT DISTINCT SPR.* 
	FROM ClientSpecialRates AS SPR 
	WHERE SPR.clsvId=@clsvId;

	/* 6 Client GeoLocations */
	SELECT DISTINCT CL.* 
	FROM ClientLocations AS CL WHERE CL.clsvId=@clsvId;

	/* 7 Client Charts */
	SELECT DISTINCT CC.* FROM 
	ClientCharts AS CC WHERE 
	CC.clsvId=@clsvId 
	ORDER BY chartId DESC;

	/* 8 Client Billing Data */
	SELECT X.*,S.ln,S.fn		
	FROM
	(
	SELECT prId,svc,Convert (DECIMAL(4,2),rat)AS rat,ws,we, SUM(un)AS un
	FROM THPLwks AS W 
	LEFT JOIN THPLHCBShrsclient AS H ON H.clsvId=@clsvId AND dt>=W.ws AND dt<=W.we
	WHERE W.ws<=CONVERT(DATE,DATEADD(WEEK,-1, GETDATE())) AND W.we>=CONVERT(DATE,DATEADD(WEEK,-1, GETDATE()))
	GROUP BY prId,svc,rat,ws,we
	)AS X
	JOIN THPLipr AS S ON S.prId=X.prId
	ORDER BY svc ASC, ln ASC,rat ASC

	/* 9 - Client Comments */
	SELECT DISTINCT CC.*,C.fn + ' ' + C.ln AS subject,S.ln + ' ' + S.fn AS commentator,'Client' AS cmtType
	FROM ClientComments AS CC
	JOIN THPLcl AS C ON C.clsvid=CC.clsvid
	JOIN THPLipr AS S ON S.prId=CC.commentatorId
	WHERE CC.clsvId=@clsvId AND cmtdt>DATEADD(DAY,-10,GETDATE())
	ORDER BY cmtDt DESC;

END












END