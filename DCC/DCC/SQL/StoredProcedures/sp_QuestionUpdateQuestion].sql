USE [THPL]
GO
/****** Object:  StoredProcedure [dbo].[sp_QuestionUpdateQuestion]    Script Date: 10/7/2019 1:40:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_QuestionUpdateQuestion]
@questionId AS INTEGER,
@valueTypeId AS INTEGER,
@title AS VARCHAR(100),
@minValue AS INTEGER NULL,
@maxValue AS INTEGER NULL,
@isActive AS BIT
AS
BEGIN
	IF @questionId = 0 
	BEGIN
		INSERT INTO Question (valueTypeId,title,minValue,maxValue,isActive)
		VALUES (@valueTypeId,@title,@minValue,@maxValue,@isActive)	
	END
	ELSE
	BEGIN
		UPDATE Question SET valueTypeId=@valueTypeId,title=@title,minValue=@minValue,maxValue=@maxValue,isActive=@isActive
		WHERE questionId=@questionId
	END
	SELECT * FROM Question
	JOIN QuestionValues ON QuestionValues.id=Question.valueTypeId
	ORDER BY title ASC

END