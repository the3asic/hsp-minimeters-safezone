-- Hammerspoon 窗口边界监控器 - 图形化安装程序
-- 自动处理 chmod +x 和在终端中运行 setup.sh

on run
	try
		-- 获取应用程序所在目录（不是Contents目录）
		set appPath to path to me
		tell application "Finder"
			set appContainer to container of appPath
			set scriptDir to appContainer as string
		end tell
		
		set setupScriptPath to scriptDir & "setup.sh"
		
		-- 转换为 POSIX 路径
		set posixScriptDir to POSIX path of scriptDir
		set posixSetupScript to POSIX path of setupScriptPath
		
		-- 检查 setup.sh 是否存在
		try
			set setupScriptFile to (setupScriptPath as alias)
		on error
			display dialog "错误：未找到 setup.sh 文件" & return & return & "请确保 installer.app 和 setup.sh 在同一个文件夹中。" & return & return & "当前查找路径：" & setupScriptPath buttons {"确定"} default button 1 with icon stop
			return
		end try
		
		-- 显示欢迎对话框
		set welcomeText to "🔨 Hammerspoon 窗口边界监控器" & return & return & "此程序将帮助您安装窗口边界监控器，为 MiniMeters 状态栏预留屏幕底部空间。" & return & return & "安装过程将在终端中进行，您可以看到详细的安装信息。"
		
		set userChoice to display dialog welcomeText buttons {"取消", "开始安装"} default button 2 with icon note
		
		if button returned of userChoice is "取消" then
			return
		end if
		
		-- 给 setup.sh 添加执行权限
		try
			do shell script "chmod +x " & quoted form of posixSetupScript
		on error errorMessage
			display dialog "错误：无法设置执行权限" & return & return & errorMessage buttons {"确定"} default button 1 with icon stop
			return
		end try
		
		-- 在终端中运行 setup.sh
		tell application "Terminal"
			activate
			
			-- 创建新窗口并运行脚本
			set newWindow to do script "cd " & quoted form of posixScriptDir & " && ./setup.sh"
			
			-- 设置窗口标题
			set custom title of newWindow to "Hammerspoon 窗口边界监控器安装程序"
			
			-- 等待一下确保窗口打开
			delay 1
		end tell
		
		-- 显示提示信息
		display dialog "✅ 安装程序已在终端中启动" & return & return & "请在终端窗口中按照提示完成安装。" & return & return & "安装完成后可以关闭终端窗口。" buttons {"确定"} default button 1 with icon note
		
	on error errorMessage number errorNumber
		display dialog "发生未知错误：" & return & return & errorMessage & return & "错误代码：" & errorNumber buttons {"确定"} default button 1 with icon stop
	end try
end run

-- 获取父目录的函数
on getParentDirectory(filePath)
	set AppleScript's text item delimiters to ":"
	set pathItems to text items of filePath
	set parentItems to items 1 thru -2 of pathItems
	set parentPath to (parentItems as string) & ":"
	set AppleScript's text item delimiters to ""
	return parentPath
end getParentDirectory