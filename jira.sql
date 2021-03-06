----已关闭JIRA，明细过滤，处理周期：
SELECT
	concat(b.pkey, '-', a.issuenum) AS "JIRA编号",
	b.pname AS "Project",
	c.pname AS "问题类型",
	a.SUMMARY AS "主题",
	a.CREATED AS "创建时间",
	a.UPDATED AS "更新时间",
	e.customvalue AS "问题级别",
	a.ASSIGNEE AS "经办人",
	concat(
		TIMESTAMPDIFF(MINUTE, a.CREATED, a.RESOLUTIONDATE) DIV 1440,
		'天',
		(
	    TIMESTAMPDIFF(MINUTE, a.CREATED, a.RESOLUTIONDATE) MOD 1440
		) DIV 60,
		'小时'
	    ) AS "处理周期（x天x小时）",
	    FORMAT(
	TIMESTAMPDIFF(HOUR, a.CREATED, a.UPDATED) / 24,2
	) AS "处理周期（x.x天）"
FROM
	jira.jiraissue a
LEFT JOIN jira.project b ON a.PROJECT = b.ID
LEFT JOIN jira.issuetype c ON a.issuetype = c.ID
LEFT JOIN jira.customfieldvalue d ON a.ID = d.ISSUE
AND d.CUSTOMFIELD = 10201
LEFT JOIN jira.customfieldoption e ON d.STRINGVALUE = e.ID
WHERE
	a.CREATED >= '2017-05-02 00:00:00'
AND a.CREATED < '2017-06-03 00:00:00'
AND a.issuetype IN (10200)
AND a.issuestatus=6 # 状态6代表已关闭
ORDER BY
	a.issuenum DESC
LIMIT 10000


---未关闭JIRA，明细过滤，处理周期
SELECT
	concat(b.pkey, '-', a.issuenum) AS "JIRA编号",
	b.pname AS "Project",
	c.pname AS "问题类型",
	a.SUMMARY AS "主题",
	a.CREATED AS "创建时间",
	a.UPDATED AS "更新时间",
	e.customvalue AS "问题级别",
	a.ASSIGNEE AS "经办人",
	concat(
		TIMESTAMPDIFF(MINUTE, a.CREATED, NOW()) DIV 1440,
		'天',
		(
	    TIMESTAMPDIFF(MINUTE, a.CREATED, NOW()) MOD 1440
		) DIV 60,
		'小时'
	    ) AS "处理周期（x天x小时）",
	    FORMAT(
	TIMESTAMPDIFF(HOUR, a.CREATED, NOW()) / 24,2
	) AS "处理周期（x.x天）"
FROM
	jira.jiraissue a
LEFT JOIN jira.project b ON a.PROJECT = b.ID
LEFT JOIN jira.issuetype c ON a.issuetype = c.ID
LEFT JOIN jira.customfieldvalue d ON a.ID = d.ISSUE
AND d.CUSTOMFIELD = 10201
LEFT JOIN jira.customfieldoption e ON d.STRINGVALUE = e.ID
WHERE
	a.CREATED >= '2017-05-02 00:00:00'
AND a.CREATED < '2017-06-13 00:00:00'
AND a.issuetype IN (10200)
AND a.issuestatus != 6 # 状态6代表已关闭
ORDER BY
	a.issuenum DESC
LIMIT 10000


---项目+问题级别+平均处理周期
SELECT
	项目名称,
	max(CASE LEVEL WHEN 'A-致命' THEN `平均处理周期（天）` ELSE null END ) "A-致命（天）",
    max(CASE LEVEL WHEN 'B-严重' THEN `平均处理周期（天）` ELSE null END ) "B-严重（天）",
	max(CASE LEVEL WHEN 'C-一般' THEN `平均处理周期（天）` ELSE null END ) "C-一般（天）",
	max(CASE LEVEL WHEN 'D-轻微' THEN `平均处理周期（天）` ELSE null END ) "D-轻微（天）",
	max(CASE LEVEL WHEN 'E-建议' THEN `平均处理周期（天）` ELSE null END ) "E-建议（天）"

FROM
	(
		SELECT
			Project AS "项目名称",
			LEVEL,
			FORMAT(AVG(Time) / 24, 2) AS "平均处理周期（天）"
		FROM
			(
				SELECT
					concat(b.pkey, '-', a.issuenum) AS "JIRA编号",
					b.pname AS "Project",
					c.pname AS "问题类型",
					a.SUMMARY AS "主题",
					a.CREATED AS "创建时间",
					a.UPDATED AS "更新时间",
					e.customvalue AS "level",
					a.ASSIGNEE AS "经办人",
					TIMESTAMPDIFF(HOUR, a.RESOLUTIONDATE, a.CREATED) AS "33",
					TIME_FORMAT(
						timediff(a.RESOLUTIONDATE, a.CREATED),
						'%Hh%im'
					) AS "Time"
				FROM
					jira.jiraissue a
				LEFT JOIN jira.project b ON a.PROJECT = b.ID
				LEFT JOIN jira.issuetype c ON a.issuetype = c.ID
				LEFT JOIN jira.customfieldvalue d ON a.ID = d.ISSUE
				AND d.CUSTOMFIELD = 10201 #10201不要改，是自定义问题级别的父节点
				LEFT JOIN jira.customfieldoption e ON d.STRINGVALUE = e.ID
				WHERE
					a.CREATED >= '2017-05-02 00:00:00'
				AND a.CREATED < '2017-06-03 00:00:00'
				AND a.issuetype IN (10200)#10200 ：线上BUG
				AND a.issuestatus=6 # 状态6代表已关闭
				ORDER BY
					a.issuenum DESC
				LIMIT 10000
			) tt
		GROUP BY
			Project,
			LEVEL
	) oo
GROUP BY
	项目名称;
展示为Null的数据，检查是否相应级别的单号为0 
  
---项目名称+不同级别的BUG数目+总平均处理周期
SELECT 
    gg.`Project` "项目名称",
    max(case level when 'A-致命' then count else 0 end) "A-致命",
    max(case level when 'B-严重' then count else 0 end) "B-严重",
    max(case level when 'C-一般' then count else 0 end) "C-一般",
    max(case level when 'D-轻微' then count else 0 end) "D-轻微",
    max(case level when 'E-建议' then count else 0 end) "E-建议",
    sum(count) "总数",
    FORMAT(sum(`平均处理周期（天）`),2) "平均处理周期（天）"
FROM
(
SELECT
	u.`项目` AS "Project",
	u.`问题级别` AS "level",
	count(1) AS "Count",
    FORMAT(AVG(Time) / 24, 2) AS "平均处理周期（天）"
FROM
	(
		SELECT
			concat(b.pkey, '-', a.issuenum) AS "JIRA编号",
			b.pname AS "项目",
			c.pname AS "问题类型",
			a.SUMMARY AS "主题",
			a.CREATED AS "创建时间",
			a.UPDATED AS "更新时间",
			e.customvalue AS "问题级别",
			a.ASSIGNEE AS "经办人",
			TIME_FORMAT(
				timediff(a.RESOLUTIONDATE, a.CREATED),
				'%Hh%im'
			) AS "Time"
		FROM
			jira.jiraissue a
		LEFT JOIN jira.project b ON a.PROJECT = b.ID
		LEFT JOIN jira.issuetype c ON a.issuetype = c.ID
		LEFT JOIN jira.customfieldvalue d ON a.ID = d.ISSUE
		AND d.CUSTOMFIELD = 10201 #无需改动
		LEFT JOIN jira.customfieldoption e ON d.STRINGVALUE = e.ID
		WHERE
			a.CREATED >= '2017-05-02 00:00:00'
		AND a.CREATED < '2017-06-03 00:00:00'
		AND a.issuetype IN (10200) #10200 ：线上BUG
		AND a.issuestatus=6 # 状态6代表已关闭
		ORDER BY
			a.issuenum DESC
		LIMIT 10000
	) u
GROUP BY
	u.`项目`,
	u.`问题级别`
) gg
GROUP BY `项目名称`;
