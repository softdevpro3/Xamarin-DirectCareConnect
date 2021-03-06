USE [DDDEZ]
GO
/****** Object:  StoredProcedure [dbo].[sp_TaskGetStaff]    Script Date: 9/15/2019 2:48:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_TaskGetStaff]
@userprId INTEGER,
@prId INTEGER,
@userLevel VARCHAR(100)
AS
BEGIN
DECLARE @fn AS VARCHAR(100)
DECLARE @ln AS VARCHAR(100)
DECLARE @staffLevel AS VARCHAR(100)
DECLARE @accessGranted AS INT = 0

/* See if we have access to targeted staff member*/
IF @userLevel='SuperAdmin' OR  @userLevel='HumanResources' OR (@userprId = @prid)
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
	SELECT @accessGranted = COUNT(*)  FROM StaffList AS I WHERE prId=@prId;

 
/* Get target staff info */
SELECT @fn=fn,@ln=ln,@stafflevel=
CASE
	WHEN isSuperAdmin<> 0 THEN 'SuperAdmin' 
	WHEN isHumanResources<> 0 THEN 'HumanResources' 
	WHEN isDirector<> 0 THEN 'Director' 
	WHEN isAssistantDirector<> 0 THEN 'AssistantDirector' 
	WHEN isSupervisor<> 0 THEN 'Supervisor'
	ELSE 'Provider'
END
FROM THPLipr WHERE prId=@prId;

/* 0 Get Staff Data */
IF @accessGranted <> 0
	SELECT @fn AS fn,@ln AS ln,@prId AS prId,@staffLevel AS staffLevel;
ELSE
	SELECT TOP 0 NULL AS x;

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
	WHERE (completed=0 OR lostSession<>0) AND deleted=0
	UNION
	SELECT CN.prId,CN.clsvId,CN.svc,CN.clAtcNoteId AS NtId,CN.Completed,CN.deleted,CN.lostSession,'ATC' AS noteType  FROM staffList AS I
	JOIN ClientNotesATC AS CN ON CN.prId=I.prId
	WHERE (completed=0 OR lostSession<>0) AND deleted=0
	UNION
	SELECT CN.prId,CN.clsvId,CN.svc,CN.clHahNoteId AS NtId,CN.Completed,CN.deleted,CN.lostSession,'HAH' AS noteType  FROM staffList AS I
	JOIN ClientNotesHAH AS CN ON CN.prId=I.prId
	WHERE (completed=0 OR lostSession<>0) AND deleted=0
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






/* 3 Staff & client Comments */
If ((@userlevel = 'SuperAdmin' OR @userlevel='HumanResources') AND (@stafflevel = 'SuperAdmin' OR @stafflevel='HumanResources'))
BEGIN
	SELECT DISTINCT SC.*,S.fn + ' ' + S.ln AS subject,S2.fn + ' ' + S2.ln AS commentator,'Staff'AS cmtType 
	FROM StaffComments AS SC 
	JOIN THPLipr AS S ON S.prid=SC.prId
	JOIN THPLipr AS S2 ON S2.prId = SC.commentatorId
	WHERE SC.cmtdt>DATEADD(DAY,-10,GETDATE())
	UNION ALL
	SELECT DISTINCT CC.*,C.fn + ' ' + C.ln AS subject,S.ln + ' ' + S.fn AS commentator,'Client' AS cmtType
	FROM ClientComments AS CC
	JOIN THPLcl AS C ON C.clsvid=CC.clsvid
	JOIN THPLipr AS S ON S.prId=CC.commentatorId
	WHERE CC.cmtdt>DATEADD(DAY,-10,GETDATE())
	ORDER BY cmtDt DESC;
END
ELSE IF @userLevel <> 'Provider'
BEGIN 
	WITH StaffList AS
	(SELECT S1.prid,1 AS eL
	FROM THPLipr AS S1
	WHERE prid=@prId
	UNION ALL
	SELECT S2.prid,SL.eL+1 AS eL
	FROM THPLipr AS S2
	INNER JOIN StaffList AS SL
	ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
	WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
	SELECT DISTINCT SC.*,S.fn + ' ' + S.ln AS subject,S2.fn + ' ' + S2.ln AS commentator,'Staff'AS cmtType FROM staffList AS I
	JOIN StaffComments AS SC ON SC.prId=I.prId  AND cmtdt>DATEADD(DAY,-10,GETDATE()) 
	JOIN THPLipr AS S ON S.prid=SC.prId
	JOIN THPLipr AS S2 ON S2.prId = SC.commentatorId
	UNION ALL
	SELECT DISTINCT CC.*,C.fn + ' ' + C.ln AS subject,S.ln + ' ' + S.fn AS commentator,'Client' AS cmtType FROM StaffList AS I
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=I.prId
	JOIN ClientComments AS CC ON CC.clsvid=CSR.clsvId
	JOIN THPLcl AS C ON C.clsvid=CC.clsvid
	JOIN THPLipr AS S ON S.prId=CC.commentatorId
	ORDER BY cmtDt DESC;
END
ELSE
BEGIN
	SELECT TOP 0 NULL AS x
END;

/* 4 New Auths */
If ((@userlevel = 'SuperAdmin' OR @userlevel='HumanResources') AND (@stafflevel = 'SuperAdmin' OR @stafflevel='HumanResources'))
BEGIN
	SELECT TOP 100 C.clsvId,CS.id AS clsvidId,C.ln+' '+C.fn AS nm,CS.svc,CA.stdt,CA.eddt,CA.au
	FROM THPlcl AS C 
	JOIN THPLclsv AS CS ON CS.clsvId=C.clsvId AND CS.deleted=0
	JOIN THPLau AS CA ON CA.clid=C.clId AND CA.seCode=CS.svc AND CA.dtRcvd>DATEADD(DAY,-4,GETDATE())
	WHERE C.deleted = 0
END
Else If @userLevel <> 'Provider'
BEGIN
	WITH StaffList AS
	(SELECT S1.prid,1 AS eL
	FROM THPLipr AS S1
	WHERE prid=@prId
	UNION ALL
	SELECT S2.prid,SL.eL+1 AS eL
	FROM THPLipr AS S2
	INNER JOIN StaffList AS SL
	ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
	WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
	SELECT DISTINCT C.clsvId,CS.id AS clsvidId,C.ln+' '+C.fn AS nm,CS.svc,CA.stdt,CA.eddt,CA.au
	FROM staffList AS I
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=I.prId
	JOIN THPLcl AS C ON C.clsvId=CSR.clsvId AND C.deleted=0
	JOIN THPLclsv AS CS ON CS.clsvId=C.clsvId AND CS.deleted=0
	JOIN THPLau AS CA ON CA.clid=C.clId AND CA.seCode=CS.svc AND CA.dtRcvd>DATEADD(DAY,-4,GETDATE())
	ORDER BY nm ASC,svc ASC;
END
ELSE
BEGIN
	SELECT TOP 0 NULL AS x
END;

/* 5 staff List */
If ((@userlevel = 'SuperAdmin' OR @userlevel='HumanResources') AND (@stafflevel = 'SuperAdmin' OR @stafflevel='HumanResources'))
BEGIN
SELECT S.prId,S.ln+' '+S.fn AS sNm,S.isDirector,S.isAssistantDirector,S.isSupervisor,S.isProvider
	FROM THPLipr AS S 
	WHERE S.deleted=0 ORDER BY sNm ASC;
END
ELSE If @userLevel <> 'Provider' AND @staffLevel <> 'Provider'
BEGIN
	WITH StaffList AS
	(SELECT S1.prid,1 AS eL
	FROM THPLipr AS S1
	WHERE prid=@prId
	UNION ALL
	SELECT S2.prid,SL.eL+1 AS eL
	FROM THPLipr AS S2
	INNER JOIN StaffList AS SL
	ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
	WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
	SELECT S.prId,S.ln+' '+S.fn AS sNm,S.isDirector,S.isAssistantDirector,S.isSupervisor,S.isProvider
	FROM staffList AS I
	JOIN THPLipr AS S ON S.prId=I.prId AND S.deleted=0 AND S.prId<>@prId ORDER BY sNm ASC;
END
ELSE
BEGIN
	SELECT TOP 0 NULL AS x
END;

/* 6 client list */
If ((@userlevel = 'SuperAdmin' OR @userlevel='HumanResources') AND (@stafflevel = 'SuperAdmin' OR @stafflevel='HumanResources'))
BEGIN
	SELECT C.clsvId,C.ln + ' ' + C.fn AS cNm
	FROM THPLcl AS C
	WHERE C.deleted=0
	ORDER BY cNm ASC;
END
ELSE IF (@userLevel = 'Provider' AND @accessGranted <> 0)
BEGIN
	SELECT C.clsvId,C.ln + ' ' + C.fn AS cNm
	FROM ClientStaffRelationships AS CSR
	JOIN THPLcl AS C ON C.clsvId=CSR.clsvId
	WHERE CSR.prId=@prId
	ORDER BY cNm ASC;
END
ELSE
BEGIN
	WITH StaffList AS
	(SELECT S1.prid,1 AS eL
	FROM THPLipr AS S1
	WHERE prid=@prId
	UNION ALL
	SELECT S2.prid,SL.eL+1 AS eL
	FROM THPLipr AS S2
	INNER JOIN StaffList AS SL
	ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
	WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
	SELECT DISTINCT C.clsvId,C.ln + ' ' + C.fn AS cNm
	FROM StaffList
	JOIN ClientStaffRelationships AS CSR ON CSR.prId=StaffList.prId
	JOIN THPLcl AS C ON C.clsvid=CSR.clsvId AND C.deleted=0
	JOIN THPLipr AS S ON S.prId=CSR.prId
	WHERE CSR.prId=StaffList.prId
	ORDER BY cNm ASC;
END;


/* 7 Credentials Staff specific */
IF (@accessGranted <> 0)
/* Always have access if own credentials or user is superadmin */
BEGIN
SELECT * FROM(
	SELECT *,
		CASE 
			WHEN R<>1 THEN 'Superseded'
			WHEN verified=1 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 'Verified'
			WHEN verified=0 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 'Not Verified'
			WHEN validTo < GETDATE() THEN 'Expired'
			WHEN validTo > DATEADD(DAY,-30, GETDATE()) THEN 'Expiring'
		ELSE 'Missing'
		END AS status,
		CASE 
			WHEN R<>1 THEN 6
			WHEN verified=1 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 5
			WHEN verified=0 AND validTo > DATEADD(DAY,30, GETDATE()) THEN 4				
			WHEN validTo < GETDATE() THEN 2
			WHEN validTo > DATEADD(DAY,-30, GETDATE()) THEN 3
			WHEN validTo IS NULL THEN 1
		END AS priority
		FROM(
			SELECT A.*,ROW_NUMBER() OVER(PARTITION BY credTypeId ORDER BY verified ASC,validTo DESC)AS R 
			FROM
				(
				SELECT ICI.credName,ICI.credTypeId,IC.credId,IC.docId,IC.validFrom,IC.validTo,IC.verified,IC.verificationDate,IC.fileExtension,I2.fn,I2.ln			
				FROM THPLipr AS S
				JOIN CredentialIds AS ICI ON
				(S.isSuperAdmin<>0 AND ICI.superadmin<>0)OR
				(S.isHumanResources<>0 AND ICI.humanResources<>0)OR
				(S.isDirector<>0 AND ICI.director<>0)OR
				(S.isAssistantDirector<>0 AND ICI.assistantdirector<>0)OR
				(S.isSupervisor<>0 AND ICI.supervisor<>0)OR
				(S.isProvider<>0 AND ICI.provider<>0)OR
				(S.profLicReq<>0 AND ICI.credTypeId=7)OR
				(S.profLiabilityReq<>0 AND ICI.credTypeId=8)OR
				(S.providesTransport='Y' AND ICI.credTypeId=9)OR
				(S.ownVehicle='Y' AND (ICI.credTypeId=10 OR ICI.credTypeId=11))
				LEFT JOIN StaffCredentials AS IC ON IC.prId=S.prId AND IC.credTypeId=ICI.credTypeId
				LEFT JOIN THPLipr AS I2 ON I2.prid=IC.verifier
				WHERE S.prid=@prId
				)AS A
			) AS B
		) AS C
	WHERE priority<=4
	ORDER BY priority asc,credname ASC, validTo ASC;
END;
ELSE

BEGIN
	/* No Access */
	SELECT TOP 0 NULL AS x
END;


/* Pending documentation late Notes Alert/ATC Monitoring Alerts / Progress notes*/
If @staffLevel ='Provider' OR @staffLevel ='Supervisor'
/* supervisor and providers are only ones with pending documentation */
BEGIN
	IF (@accessGranted <>0)
	/* Always have access */
	BEGIN
		If @staffLevel='Provider'
		BEGIN
			/* Hab progress report incomplete */
			SELECT S.fn AS sfn,S.ln AS sln,S.prId,C.fn AS cfn,C.ln AS cln,C.clsvId, 
			CHPR.svc + ' progress report for ' + C.fn + ' ' + C.ln + ' not completed, due ' + CONVERT(varchar(11),CHPR.dueDt,101) AS msg,
			'HabReport' As docType,
			CHPR.progressHabId AS docId,
			completed,
			verified,
			0 AS lostSession
			FROM ClientStaffRelationships AS CSR 
			JOIN ClientHABProgressReport AS CHPR ON CHPR.clsvId=CSR.clsvId AND CHPR.completed=0 AND deleted=0
			JOIN THPLipr AS S ON S.prId=CSR.prId
			JOIN THPLcl AS C ON C.clsvId=CHPR.clsvId
			WHERE CSR.prid=@prId
			UNION
			/* Late notes*/
			SELECT S.fn AS sfn,S.ln AS sln,S.prId,C.fn AS cfn,C.ln AS cln,C.clsvId,
			CASE 
				WHEN N.lostSession<> 0 THEN N.svc + ' Client Note for ' + C.fn + ' ' + C.ln + ' session lost'
				ELSE N.svc+ ' Client Note for ' + C.fn + ' ' + C.ln + ' incomplete'
			END AS msg,
			docType,
			docId,
			completed,
			CAST(0 AS bit) AS verified,
			lostSession	
			FROM
				(
				SELECT prId,clsvId,svc,clRspNoteId AS docId,Completed,deleted,lostSession,'RSPServiceNote' AS docType
				FROM ClientNotesRSP 
				WHERE prId=@prId AND (completed=0 OR lostSession<>0) AND deleted=0
				UNION
				SELECT prId,clsvId,svc,clAtcNoteId AS docId,Completed,deleted,lostSession,'ATCServiceNote' AS docType
				FROM ClientNotesATC
				WHERE prId=@prId AND (completed=0 OR lostSession<>0) AND deleted=0
				UNION
				SELECT prId,clsvId,svc,clHahNoteId AS docId,Completed,deleted,lostSession,'HAHServiceNote' AS docType
				FROM ClientNotesHAH
				WHERE prId=@prId AND (completed=0 OR lostSession<>0) AND deleted=0
				) AS N
			JOIN THPLipr AS S ON S.prid=@prId
			JOIN THPLcl AS C ON C.clsvId=N.clsvId
		END
		If @Stafflevel='Supervisor'
		BEGIN
		WITH StaffList AS
		(SELECT S1.prid,1 AS eL
		FROM THPLipr AS S1
		WHERE prid=847
		UNION ALL
		SELECT S2.prid,SL.eL+1 AS eL
		FROM THPLipr AS S2
		INNER JOIN StaffList AS SL
		ON S2.supPrid=SL.prId OR S2.tempsupPrid=SL.prId
		WHERE S2.prid<>0 AND S2.prID IS NOT NULL)
		SELECT S.fn AS sfn,S.ln AS sln,S.prId,C.fn AS cfn,C.ln AS cln,C.clsvId, 
		CHPR.svc + ' progress report for ' + C.fn + ' ' + C.ln + ' not verified, due ' + CONVERT(varchar(11),CHPR.dueDt,101) AS msg,
		'HabReport' As docType,
		CHPR.progressHabId AS docId,
		completed,
		verified,
		0 AS lostSession
		FROM staffList AS I
		JOIN THPLipr AS S ON S.prId=I.prId
		JOIN ClientStaffRelationships AS CSR ON CSR.prId=S.prId
		JOIN ClientHABProgressReport AS CHPR ON CHPR.clsvId=CSR.clsvId AND CHPR.completed<>0 AND verified=0 AND CHPR.deleted=0		
		JOIN THPLcl AS C ON C.clsvId=CHPR.clsvId
		UNION
		SELECT S.fn AS sfn, S.ln AS sln,S.prId,C.fn AS cfn,C.ln AS cln,C.clsvId,
		CAM.svc + ' monitoring due for ' + C.fn + ' ' + C.ln + ' due ' + CONVERT(varchar(11),CAM.dueDt,101) AS msg,
		'MonitoringNote' As docType,
		CAM.atcMonitorId AS docId,
		completed,
		CAST(0 AS bit) AS verified,
		CAST(0 AS bit) AS lostSession
		FROM StaffList AS I
		JOIN THPLipr AS S ON S.prId=I.prId
		JOIN ClientStaffRelationships AS CSR ON CSR.prId=S.prId
		JOIN ClientATCMonitoring AS CAM ON CAM.clsvId=CSR.clsvId AND CAM.completed=0 AND CAM.deleted=0 AND DATEADD(DAY,-14,CAM.dueDt)<GETDate()
		JOIN THPLcl AS C ON C.clsvId=CAM.clsvId;
		END;	
	END;
END;
ELSE
BEGIN
	/* No Access */
	SELECT TOP 0 NULL AS x
END;







/* 9 billing data */
If @staffLevel ='Provider' 
	BEGIN
		SELECT ws,we,svc, CAST(rat AS DECimal(2, 1)) AS rat, SUM(un)AS un FROM
			(
			SELECT DISTINCT H.svc,H.un,H.dt,H.in1,H.out1,H.rat,W.ws,W.we
			FROM THPLipr AS S
			JOIN THPLwks AS W ON W.ws<=CONVERT(DATE,DATEADD(WEEK,-1, GETDATE())) AND W.we>=CONVERT(DATE,DATEADD(WEEK,-1, GETDATE()))
			LEFT JOIN THPLHCBShrsclient AS H ON H.prId=S.prId AND dt>=W.ws AND dt<=W.we
			WHERE S.prId=@prId
			) AS X
		GROUP BY svc,rat,ws,we ORDER BY svc ASC, rat ASC
	END
ELSE
	BEGIN
		SELECT TOP 0 NULL AS x
	END



END