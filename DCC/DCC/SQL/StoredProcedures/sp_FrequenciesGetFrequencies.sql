USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_FrequenciesGetFrequencies]    Script Date: 10/8/2019 11:49:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_FrequenciesGetFrequencies]

AS
BEGIN
	SELECT * FROM Duration
	ORDER BY name ASC
	SELECT * FROM DurationDiscipline
END