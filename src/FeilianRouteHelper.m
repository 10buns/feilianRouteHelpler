#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property NSWindow *window;
@property NSTextView *hostsTextView;
@property NSTextView *logTextView;
@property NSTextField *proxyConfigField;
@property NSString *configPath;
@property NSString *scriptPath;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self preparePaths];
    [self buildMenu];
    [self buildWindow];
    [self loadHosts:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)preparePaths {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *supportDir = [[dirs firstObject] stringByAppendingPathComponent:@"FeilianRouteHelper"];
    [[NSFileManager defaultManager] createDirectoryAtPath:supportDir withIntermediateDirectories:YES attributes:nil error:nil];
    self.configPath = [supportDir stringByAppendingPathComponent:@"hosts.conf"];
    self.scriptPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"bind-feilian-routes.sh"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:self.configPath]) {
        [@"devplatform-cn.bwcj.biz\n" writeToFile:self.configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 860, 640)
                                             styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    self.window.title = @"飞连路由助手";
    [self.window center];

    NSView *content = self.window.contentView;

    NSTextField *hostsLabel = [self labelWithString:@"域名配置（每行一个完整域名，不支持通配符，可复制粘贴）" frame:NSMakeRect(20, 598, 520, 22)];
    [content addSubview:hostsLabel];

    NSScrollView *hostsScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 405, 820, 190)];
    hostsScroll.hasVerticalScroller = YES;
    hostsScroll.borderType = NSBezelBorder;
    self.hostsTextView = [[NSTextView alloc] initWithFrame:hostsScroll.bounds];
    self.hostsTextView.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    self.hostsTextView.automaticQuoteSubstitutionEnabled = NO;
    self.hostsTextView.automaticDashSubstitutionEnabled = NO;
    hostsScroll.documentView = self.hostsTextView;
    [content addSubview:hostsScroll];

    NSButton *saveButton = [self buttonWithTitle:@"保存域名" action:@selector(saveHosts:) frame:NSMakeRect(20, 365, 100, 32)];
    NSButton *loadButton = [self buttonWithTitle:@"重新读取" action:@selector(loadHosts:) frame:NSMakeRect(130, 365, 100, 32)];
    NSButton *redirectButton = [self buttonWithTitle:@"补全跳转域名" action:@selector(discoverRedirectHosts:) frame:NSMakeRect(240, 365, 130, 32)];
    NSButton *bindButton = [self buttonWithTitle:@"绑定飞连路由" action:@selector(bindRoutes:) frame:NSMakeRect(380, 365, 130, 32)];
    NSButton *terminalBindButton = [self buttonWithTitle:@"终端执行绑定" action:@selector(openTerminalBind:) frame:NSMakeRect(520, 365, 120, 32)];
    NSButton *clearButton = [self buttonWithTitle:@"清空日志" action:@selector(clearLogs:) frame:NSMakeRect(650, 365, 100, 32)];
    [content addSubview:saveButton];
    [content addSubview:loadButton];
    [content addSubview:redirectButton];
    [content addSubview:bindButton];
    [content addSubview:terminalBindButton];
    [content addSubview:clearButton];

    NSTextField *configLabel = [self labelWithString:@"代理配置文件（写入真实解析 + DIRECT 规则）" frame:NSMakeRect(20, 326, 520, 22)];
    [content addSubview:configLabel];

    self.proxyConfigField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 292, 570, 28)];
    self.proxyConfigField.placeholderString = @"选择 Shadowrocket/Clash 配置文件";
    [content addSubview:self.proxyConfigField];

    NSButton *chooseConfigButton = [self buttonWithTitle:@"选择配置" action:@selector(chooseProxyConfig:) frame:NSMakeRect(602, 290, 110, 32)];
    NSButton *applyRulesButton = [self buttonWithTitle:@"写入代理规则" action:@selector(applyProxyRules:) frame:NSMakeRect(722, 290, 118, 32)];
    [content addSubview:chooseConfigButton];
    [content addSubview:applyRulesButton];

    NSTextField *logLabel = [self labelWithString:@"绑定日志" frame:NSMakeRect(20, 258, 200, 22)];
    [content addSubview:logLabel];

    NSScrollView *logScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 38, 820, 217)];
    logScroll.hasVerticalScroller = YES;
    logScroll.borderType = NSBezelBorder;
    self.logTextView = [[NSTextView alloc] initWithFrame:logScroll.bounds];
    self.logTextView.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.logTextView.editable = NO;
    logScroll.documentView = self.logTextView;
    [content addSubview:logScroll];

    NSTextField *authorLabel = [self labelWithString:@"Author: @10buns | Email: loverichy8@gmail.com" frame:NSMakeRect(20, 12, 420, 20)];
    authorLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    authorLabel.textColor = [NSColor secondaryLabelColor];
    [content addSubview:authorLabel];

    [self appendLog:@"提示：飞连连接后，点击“绑定飞连路由”。系统会请求管理员权限用于添加路由。\n"];
    [self appendLog:@"提示：如果日志出现 must be root，请点击“终端执行绑定”，在 Terminal 中输入 sudo 密码执行。\n"];
    [self appendLog:@"提示：如果网页访问发生 30x 跳转，先点击“补全跳转域名”，再写入代理规则并绑定飞连路由。\n"];
    [self appendLog:@"提示：如需修改 Shadowrocket/Clash 配置，先选择配置文件，再点击“写入代理规则”。写入前会自动备份。\n"];
    [self appendLog:@"说明：Shadowrocket 写入 always-real-ip + DIRECT；Clash/Mihomo 写入 fake-ip-filter + DIRECT，fake-ip-filter 是否生效取决于客户端内核。\n"];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)buildMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"飞连路由助手"];
    [appMenu addItemWithTitle:@"退出飞连路由助手" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
    [editMenu addItemWithTitle:@"撤销" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"重做" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"复制" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"粘贴" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;

    [NSApp setMainMenu:mainMenu];
}

- (NSTextField *)labelWithString:(NSString *)string frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = string;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    return label;
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action frame:(NSRect)frame {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.title = title;
    button.bezelStyle = NSBezelStyleRounded;
    button.target = self;
    button.action = action;
    return button;
}

- (void)loadHosts:(id)sender {
    NSString *hosts = [NSString stringWithContentsOfFile:self.configPath encoding:NSUTF8StringEncoding error:nil];
    self.hostsTextView.string = hosts ?: @"devplatform-cn.bwcj.biz\n";
    [self appendLog:[NSString stringWithFormat:@"已读取域名配置：%@\n", self.configPath]];
}

- (void)saveHosts:(id)sender {
    NSString *cleaned = [self cleanedHostsFromString:self.hostsTextView.string];
    if (cleaned.length == 0) {
        [self appendLog:@"保存失败：域名列表不能为空。\n"];
        return;
    }
    NSError *error = nil;
    [cleaned writeToFile:self.configPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        [self appendLog:[NSString stringWithFormat:@"保存失败：%@\n", error.localizedDescription]];
    } else {
        self.hostsTextView.string = cleaned;
        [self appendLog:@"域名配置已保存。\n"];
    }
}

- (NSString *)cleanedHostsFromString:(NSString *)input {
    NSMutableOrderedSet<NSString *> *hosts = [NSMutableOrderedSet orderedSet];
    NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *lines = [input componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9.-]+$" options:0 error:nil];

    for (NSString *line in lines) {
        NSString *host = [line stringByTrimmingCharactersInSet:trimSet];
        if (host.length == 0 || [host hasPrefix:@"#"]) {
            continue;
        }
        host = [self hostFromInput:host] ?: host;
        if ([host containsString:@"*"]) {
            [self appendLog:[NSString stringWithFormat:@"跳过通配符域名：%@\n", host]];
            continue;
        }
        NSUInteger matches = [regex numberOfMatchesInString:host options:0 range:NSMakeRange(0, host.length)];
        if (matches == 0) {
            [self appendLog:[NSString stringWithFormat:@"跳过非法域名：%@\n", host]];
            continue;
        }
        [hosts addObject:host.lowercaseString];
    }

    NSMutableString *result = [NSMutableString string];
    for (NSString *host in hosts) {
        [result appendFormat:@"%@\n", host];
    }
    return result;
}

- (NSString *)hostFromInput:(NSString *)input {
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURLComponents *components = [NSURLComponents componentsWithString:trimmed];
    if (components.host.length > 0) {
        return components.host.lowercaseString;
    }

    if ([trimmed containsString:@"://"]) {
        return nil;
    }

    components = [NSURLComponents componentsWithString:[@"https://" stringByAppendingString:trimmed]];
    return components.host.lowercaseString;
}

- (void)discoverRedirectHosts:(id)sender {
    NSString *cleaned = [self cleanedHostsFromString:self.hostsTextView.string];
    NSArray<NSString *> *hosts = [self hostsFromCleanedString:cleaned];
    if (hosts.count == 0) {
        [self appendLog:@"跳转检测失败：域名列表为空。\n"];
        return;
    }

    NSMutableOrderedSet<NSString *> *merged = [NSMutableOrderedSet orderedSetWithArray:hosts];
    [self appendLog:@"开始检测 30x 跳转域名...\n"];

    for (NSString *host in hosts) {
        for (NSString *scheme in @[@"https", @"http"]) {
            NSString *url = [NSString stringWithFormat:@"%@://%@", scheme, host];
            for (NSString *redirectHost in [self redirectHostsForURL:url]) {
                if (redirectHost.length == 0 || [redirectHost isEqualToString:host]) {
                    continue;
                }
                if (![merged containsObject:redirectHost]) {
                    [merged addObject:redirectHost];
                    [self appendLog:[NSString stringWithFormat:@"发现跳转域名：%@ -> %@\n", host, redirectHost]];
                }
            }
        }
    }

    NSMutableString *result = [NSMutableString string];
    for (NSString *host in merged) {
        [result appendFormat:@"%@\n", host];
    }
    self.hostsTextView.string = result;
    [result writeToFile:self.configPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self appendLog:@"跳转域名检测完成，域名配置已保存。请重新写入代理规则并绑定飞连路由。\n"];
}

- (NSArray<NSString *> *)hostsFromCleanedString:(NSString *)cleaned {
    NSMutableArray<NSString *> *hosts = [NSMutableArray array];
    for (NSString *line in [cleaned componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *host = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (host.length > 0) {
            [hosts addObject:host];
        }
    }
    return hosts;
}

- (NSArray<NSString *> *)redirectHostsForURL:(NSString *)url {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/curl";
    task.arguments = @[@"-kLsS", @"-D", @"-", @"-o", @"/dev/null", @"--connect-timeout", @"5", @"--max-time", @"15", @"--max-redirs", @"8", @"-w", @"\n__FINAL_URL__%{url_effective}\n", url];

    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        [self appendLog:[NSString stringWithFormat:@"跳转检测执行失败：%@\n", url]];
        return @[];
    }

    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (task.terminationStatus != 0 || output.length == 0) {
        [self appendLog:[NSString stringWithFormat:@"未检测到跳转：%@\n", url]];
        return @[];
    }

    NSMutableOrderedSet<NSString *> *hosts = [NSMutableOrderedSet orderedSet];
    for (NSString *line in [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *candidate = nil;
        if ([trimmed.lowercaseString hasPrefix:@"location:"]) {
            candidate = [trimmed substringFromIndex:[@"location:" length]];
        } else if ([trimmed hasPrefix:@"__FINAL_URL__"]) {
            candidate = [trimmed substringFromIndex:[@"__FINAL_URL__" length]];
        }

        NSString *host = [self hostFromInput:[candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @""];
        if (host.length > 0) {
            [hosts addObject:host];
        }
    }
    return hosts.array;
}

- (void)bindRoutes:(id)sender {
    [self saveHosts:nil];
    [self appendLog:@"开始绑定飞连路由...\n"];

    AuthorizationRef auth = NULL;
    AuthorizationItem item = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &item };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    OSStatus status = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment, flags, &auth);
    if (status != errAuthorizationSuccess || auth == NULL) {
        [self appendLog:[NSString stringWithFormat:@"授权失败：%d\n", (int)status]];
        return;
    }

    const char *tool = "/bin/bash";
    char *args[] = {
        (char *)[self.scriptPath fileSystemRepresentation],
        (char *)[self.configPath fileSystemRepresentation],
        NULL
    };
    FILE *pipe = NULL;
    status = AuthorizationExecuteWithPrivileges(auth, tool, kAuthorizationFlagDefaults, args, &pipe);
    if (status != errAuthorizationSuccess) {
        [self appendLog:[NSString stringWithFormat:@"执行失败：%d\n", (int)status]];
        AuthorizationFree(auth, kAuthorizationFlagDefaults);
        return;
    }

    if (pipe) {
        char buffer[4096];
        while (fgets(buffer, sizeof(buffer), pipe) != NULL) {
            NSString *line = [NSString stringWithUTF8String:buffer];
            if (line) {
                [self appendLog:line];
            }
        }
        fclose(pipe);
    }

    AuthorizationFree(auth, kAuthorizationFlagDefaults);
    [self appendLog:@"绑定完成。\n"];
}

- (NSString *)shellQuoted:(NSString *)value {
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

- (void)openTerminalBind:(id)sender {
    [self saveHosts:nil];

    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *supportDir = [[dirs firstObject] stringByAppendingPathComponent:@"FeilianRouteHelper"];
    [[NSFileManager defaultManager] createDirectoryAtPath:supportDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *commandPath = [supportDir stringByAppendingPathComponent:@"bind-routes.command"];

    NSString *command = [NSString stringWithFormat:
        @"#!/bin/bash\n"
         "clear\n"
         "echo '飞连路由助手 - 终端执行绑定'\n"
         "echo '需要输入当前 macOS 用户密码以获取 sudo 权限。'\n"
         "echo\n"
         "sudo /bin/bash %@ %@\n"
         "STATUS=$?\n"
         "echo\n"
         "if [ \"$STATUS\" -eq 0 ]; then\n"
         "  echo '执行完成。'\n"
         "else\n"
         "  echo \"执行失败，退出码：$STATUS\"\n"
         "fi\n"
         "echo\n"
         "read -r -p '按回车关闭窗口...'\n",
         [self shellQuoted:self.scriptPath],
         [self shellQuoted:self.configPath]];

    NSError *error = nil;
    if (![command writeToFile:commandPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self appendLog:[NSString stringWithFormat:@"生成终端执行脚本失败：%@\n", error.localizedDescription]];
        return;
    }
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:commandPath error:nil];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[@"-a", @"Terminal", commandPath];
    @try {
        [task launch];
        [self appendLog:@"已打开 Terminal 执行绑定命令，请在终端中输入 sudo 密码。\n"];
    } @catch (NSException *exception) {
        [self appendLog:[NSString stringWithFormat:@"打开 Terminal 失败：%@\n", exception.reason]];
    }
}

- (NSArray<NSString *> *)currentHosts {
    NSString *cleaned = [self cleanedHostsFromString:self.hostsTextView.string];
    NSMutableArray<NSString *> *hosts = [NSMutableArray array];
    for (NSString *line in [cleaned componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *host = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (host.length > 0) {
            [hosts addObject:host];
        }
    }
    return hosts;
}

- (NSArray<NSString *> *)suffixesForHosts:(NSArray<NSString *> *)hosts {
    NSMutableOrderedSet<NSString *> *suffixes = [NSMutableOrderedSet orderedSet];
    for (NSString *host in hosts) {
        NSArray<NSString *> *parts = [host componentsSeparatedByString:@"."];
        if (parts.count >= 2) {
            NSString *suffix = [NSString stringWithFormat:@"%@.%@", parts[parts.count - 2], parts[parts.count - 1]];
            [suffixes addObject:suffix.lowercaseString];
        }
    }
    return suffixes.array;
}

- (void)chooseProxyConfig:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedFileTypes = @[@"conf", @"yaml", @"yml"];
    panel.title = @"选择 Shadowrocket 或 Clash 配置文件";

    if ([panel runModal] == NSModalResponseOK) {
        self.proxyConfigField.stringValue = panel.URL.path;
        [self appendLog:[NSString stringWithFormat:@"已选择配置文件：%@\n", panel.URL.path]];
    }
}

- (void)applyProxyRules:(id)sender {
    [self saveHosts:nil];
    NSString *path = [self.proxyConfigField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (path.length == 0) {
        [self appendLog:@"请先选择代理配置文件。\n"];
        return;
    }

    NSArray<NSString *> *hosts = [self currentHosts];
    if (hosts.count == 0) {
        [self appendLog:@"域名列表为空，无法写入代理规则。\n"];
        return;
    }

    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error || content.length == 0) {
        [self appendLog:[NSString stringWithFormat:@"读取配置失败：%@\n", error.localizedDescription ?: path]];
        return;
    }

    NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
    NSString *backupPath = [path stringByAppendingFormat:@".bak.%@", timestamp];
    if (![content writeToFile:backupPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self appendLog:[NSString stringWithFormat:@"备份失败：%@\n", error.localizedDescription]];
        return;
    }

    NSString *ext = path.pathExtension.lowercaseString;
    NSString *updated = nil;
    if ([ext isEqualToString:@"conf"]) {
        updated = [self updatedShadowrocketConf:content hosts:hosts];
    } else if ([ext isEqualToString:@"yaml"] || [ext isEqualToString:@"yml"]) {
        updated = [self updatedClashYaml:content hosts:hosts];
    } else {
        [self appendLog:@"不支持的配置文件类型，请选择 .conf / .yaml / .yml。\n"];
        return;
    }

    if (![updated writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self appendLog:[NSString stringWithFormat:@"写入失败：%@\n", error.localizedDescription]];
        [self appendLog:[NSString stringWithFormat:@"原配置备份在：%@\n", backupPath]];
        return;
    }

    [self appendLog:[NSString stringWithFormat:@"代理规则已写入：%@\n", path]];
    [self appendLog:[NSString stringWithFormat:@"原配置已备份：%@\n", backupPath]];
    if ([ext isEqualToString:@"conf"]) {
        [self appendLog:@"已写入 Shadowrocket .conf：always-real-ip + DOMAIN/DIRECT 规则。\n"];
    } else {
        [self appendLog:@"已写入 Clash/Mihomo YAML：fake-ip-filter + DOMAIN/DIRECT 规则。fake-ip-filter 是否生效取决于客户端内核。\n"];
    }
    [self flushDNSCache];
    [self appendLog:@"请在 Shadowrocket/Clash 中重新加载该配置。\n"];
}

- (void)flushDNSCache {
    [self appendLog:@"开始刷新 macOS DNS 缓存...\n"];

    AuthorizationRef auth = NULL;
    AuthorizationItem item = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &item };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    OSStatus status = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment, flags, &auth);
    if (status != errAuthorizationSuccess || auth == NULL) {
        [self appendLog:[NSString stringWithFormat:@"DNS 刷新授权失败：%d\n", (int)status]];
        return;
    }

    const char *tool = "/bin/bash";
    char *args[] = {
        "-c",
        "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder",
        NULL
    };
    FILE *pipe = NULL;
    status = AuthorizationExecuteWithPrivileges(auth, tool, kAuthorizationFlagDefaults, args, &pipe);
    if (status != errAuthorizationSuccess) {
        [self appendLog:[NSString stringWithFormat:@"DNS 刷新失败：%d\n", (int)status]];
        AuthorizationFree(auth, kAuthorizationFlagDefaults);
        return;
    }

    if (pipe) {
        char buffer[1024];
        while (fgets(buffer, sizeof(buffer), pipe) != NULL) {
            NSString *line = [NSString stringWithUTF8String:buffer];
            if (line) {
                [self appendLog:line];
            }
        }
        fclose(pipe);
    }

    AuthorizationFree(auth, kAuthorizationFlagDefaults);
    [self appendLog:@"DNS 缓存已刷新。\n"];
}

- (NSString *)updatedShadowrocketConf:(NSString *)content hosts:(NSArray<NSString *> *)hosts {
    NSMutableOrderedSet<NSString *> *realIpValues = [NSMutableOrderedSet orderedSetWithArray:hosts];
    for (NSString *suffix in [self suffixesForHosts:hosts]) {
        [realIpValues addObject:suffix];
        [realIpValues addObject:[@"*." stringByAppendingString:suffix]];
    }

    NSMutableArray<NSString *> *lines = [[content componentsSeparatedByString:@"\n"] mutableCopy];
    [self mergeConfKey:@"always-real-ip" values:realIpValues.array inSection:@"General" lines:lines];

    NSMutableArray<NSString *> *rules = [NSMutableArray array];
    for (NSString *suffix in [self suffixesForHosts:hosts]) {
        [rules addObject:[NSString stringWithFormat:@"DOMAIN-SUFFIX,%@,DIRECT", suffix]];
    }
    for (NSString *host in hosts) {
        [rules addObject:[NSString stringWithFormat:@"DOMAIN,%@,DIRECT", host]];
    }
    [self insertRules:rules inConfLines:lines];
    return [lines componentsJoinedByString:@"\n"];
}

- (void)mergeConfKey:(NSString *)key values:(NSArray<NSString *> *)values inSection:(NSString *)section lines:(NSMutableArray<NSString *> *)lines {
    NSInteger start = -1;
    NSInteger end = lines.count;
    NSString *sectionHeader = [NSString stringWithFormat:@"[%@]", section];

    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        NSString *trimmed = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed caseInsensitiveCompare:sectionHeader] == NSOrderedSame) {
            start = i;
            for (NSInteger j = i + 1; j < (NSInteger)lines.count; j++) {
                NSString *next = [lines[j] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([next hasPrefix:@"["] && [next hasSuffix:@"]"]) {
                    end = j;
                    break;
                }
            }
            break;
        }
    }

    if (start == -1) {
        [lines insertObject:[NSString stringWithFormat:@"%@ = %@", key, [values componentsJoinedByString:@", "]] atIndex:0];
        [lines insertObject:sectionHeader atIndex:0];
        return;
    }

    NSString *keyPrefix = [key stringByAppendingString:@"="];
    for (NSInteger i = start + 1; i < end; i++) {
        NSString *compact = [[lines[i] stringByReplacingOccurrencesOfString:@" " withString:@""] lowercaseString];
        if ([compact hasPrefix:keyPrefix.lowercaseString]) {
            NSArray<NSString *> *parts = [lines[i] componentsSeparatedByString:@"="];
            NSMutableOrderedSet<NSString *> *merged = [NSMutableOrderedSet orderedSet];
            if (parts.count > 1) {
                NSString *existing = [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@"="];
                for (NSString *value in [existing componentsSeparatedByString:@","]) {
                    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (trimmed.length > 0) {
                        [merged addObject:trimmed];
                    }
                }
            }
            for (NSString *value in values) {
                [merged addObject:value];
            }
            lines[i] = [NSString stringWithFormat:@"%@ = %@", key, [merged.array componentsJoinedByString:@", "]];
            return;
        }
    }

    [lines insertObject:[NSString stringWithFormat:@"%@ = %@", key, [values componentsJoinedByString:@", "]] atIndex:start + 1];
}

- (void)insertRules:(NSArray<NSString *> *)rules inConfLines:(NSMutableArray<NSString *> *)lines {
    NSInteger ruleStart = -1;
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        NSString *trimmed = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed caseInsensitiveCompare:@"[Rule]"] == NSOrderedSame) {
            ruleStart = i;
            break;
        }
    }

    if (ruleStart == -1) {
        [lines addObject:@""];
        [lines addObject:@"[Rule]"];
        ruleStart = lines.count - 1;
    }

    NSMutableSet<NSString *> *existing = [NSMutableSet set];
    for (NSString *line in lines) {
        [existing addObject:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }

    NSInteger insertIndex = ruleStart + 1;
    for (NSString *rule in [rules reverseObjectEnumerator]) {
        if (![existing containsObject:rule]) {
            [lines insertObject:rule atIndex:insertIndex];
        }
    }
}

- (NSString *)updatedClashYaml:(NSString *)content hosts:(NSArray<NSString *> *)hosts {
    NSMutableArray<NSString *> *lines = [[content componentsSeparatedByString:@"\n"] mutableCopy];
    NSArray<NSString *> *suffixes = [self suffixesForHosts:hosts];

    NSMutableArray<NSString *> *filterItems = [NSMutableArray array];
    for (NSString *suffix in suffixes) {
        [filterItems addObject:[NSString stringWithFormat:@"    - '%@'", suffix]];
        [filterItems addObject:[NSString stringWithFormat:@"    - '*.%@'", suffix]];
    }
    for (NSString *host in hosts) {
        [filterItems addObject:[NSString stringWithFormat:@"    - '%@'", host]];
    }
    [self insertYamlItems:filterItems underKey:@"fake-ip-filter:" parentKey:@"dns:" lines:lines];

    NSMutableArray<NSString *> *ruleItems = [NSMutableArray array];
    for (NSString *suffix in suffixes) {
        [ruleItems addObject:[NSString stringWithFormat:@"  - DOMAIN-SUFFIX,%@,DIRECT", suffix]];
    }
    for (NSString *host in hosts) {
        [ruleItems addObject:[NSString stringWithFormat:@"  - DOMAIN,%@,DIRECT", host]];
    }
    [self insertYamlItems:ruleItems underKey:@"rules:" parentKey:nil lines:lines];

    return [lines componentsJoinedByString:@"\n"];
}

- (void)insertYamlItems:(NSArray<NSString *> *)items underKey:(NSString *)key parentKey:(NSString *)parentKey lines:(NSMutableArray<NSString *> *)lines {
    NSMutableSet<NSString *> *existing = [NSMutableSet set];
    for (NSString *line in lines) {
        [existing addObject:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }

    NSInteger keyIndex = -1;
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        NSString *trimmed = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed isEqualToString:key]) {
            keyIndex = i;
            break;
        }
    }

    if (keyIndex == -1 && parentKey.length > 0) {
        NSInteger parentIndex = -1;
        for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
            NSString *trimmed = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed isEqualToString:parentKey]) {
                parentIndex = i;
                break;
            }
        }
        if (parentIndex == -1) {
            [lines addObject:@""];
            [lines addObject:parentKey];
            parentIndex = lines.count - 1;
        }
        [lines insertObject:[@"  " stringByAppendingString:key] atIndex:parentIndex + 1];
        keyIndex = parentIndex + 1;
    }

    if (keyIndex == -1) {
        [lines addObject:@""];
        [lines addObject:key];
        keyIndex = lines.count - 1;
    }

    NSInteger insertIndex = keyIndex + 1;
    for (NSString *item in [items reverseObjectEnumerator]) {
        NSString *trimmedItem = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (![existing containsObject:trimmedItem]) {
            [lines insertObject:item atIndex:insertIndex];
        }
    }
}

- (void)clearLogs:(id)sender {
    self.logTextView.string = @"";
}

- (void)appendLog:(NSString *)message {
    NSString *timestamp = [[NSDate date] descriptionWithLocale:nil];
    NSString *line = [NSString stringWithFormat:@"[%@] %@", timestamp, message];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTextStorage *storage = self.logTextView.textStorage;
        [storage appendAttributedString:[[NSAttributedString alloc] initWithString:line]];
        [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.string.length, 0)];
    });
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app activateIgnoringOtherApps:YES];
        [app run];
    }
    return 0;
}
