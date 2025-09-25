# borg-calendar

[Switch to English version](README_en.md)

borg-calendar 是一个用于查看 [Borg Backup](https://www.borgbackup.org/) 备份记录的可视化日历工具，旨在帮助用户直观地了解备份的历史执行情况。


## 功能特点

- 以月历或年历形式展示 Borg Backup 的备份历史
- 反转高亮显示有备份记录的日期
- 支持本地和远程 Borg 仓库
- 灵活的参数配置和环境变量支持
- 自动检测备份时间范围并显示
- 智能密码处理机制，避免在命令行中暴露密码
- 性能优化，减少对 Borg 仓库的重复查询

## 安装要求

- [Borg Backup](https://www.borgbackup.org/) 1.0 或更高版本
- Bash 4.0 或更高版本
- 基本的 Unix 工具 (grep, sort 等)

## 安装步骤

1. 克隆或下载本仓库
```bash
git clone https://github.com/haotianfei/borg-calendar.git
cd borg-calendar
```
2. 确保 `borg-calendar.sh` 文件具有可执行权限：
   ```bash
   chmod +x borg-calendar.sh
   ```

## 使用方法

```bash
./borg-calendar.sh [选项] [年份] [月份]
```

### 参数说明

- `年份`：要显示的年份（如 2025）
- `月份`：要显示的月份（1-12）

### 选项

- `--borg-repo PATH`：指定 Borg 仓库路径（优先级最高）
- `--help, -h`：显示帮助信息

### 环境变量

- `BORG_REPO`：指定 Borg 仓库路径（优先级中等，默认是当前目录）
- `BORG_PASSPHRASE`：Borg 仓库密码（如果未设置，脚本会提示输入）

### 仓库路径优先级

命令行参数 > 环境变量 BORG_REPO > 当前路径

### 密码处理机制

脚本会智能处理密码：
- 如果已设置 `BORG_PASSPHRASE` 环境变量，则直接使用
- 如果未设置，则尝试无密码访问仓库
- 只有在确认需要密码时才提示用户输入
- 密码在整个脚本执行期间有效，避免重复输入
- 脚本退出时自动清除密码

### 帮助信息

可以通过以下命令查看帮助信息：

```bash
./borg-calendar.sh --help
```

完整的帮助信息如下：

```
用法: ./borg-calendar.sh [选项] [年份] [月份]

显示 Borg 备份日历，有备份的日期会以反转色高亮。

参数:
    年份        要显示的年份（如 2025）
    月份        要显示的月份（1-12）

选项:
    --borg-repo PATH   指定 Borg 仓库路径（优先级最高）

环境变量:
    BORG_REPO   指定 Borg 仓库路径（优先级中等，默认是当前目录）

示例:
    ./borg-calendar.sh                              # 显示从最早到最晚的所有备份月份
    ./borg-calendar.sh --borg-repo /path/to/repo    # 使用指定的仓库路径
    ./borg-calendar.sh 2025                         # 显示 2025 年全年日历
    ./borg-calendar.sh 2025 7                       # 显示 2025 年 7 月
    ./borg-calendar.sh 7                            # 显示今年 7 月

注意：
    归档是否存在的判断基于 {start} 时间字段，与归档名无关。
    仓库路径优先级：命令行参数 > 环境变量 BORG_REPO > 当前路径
```

帮助信息会根据系统语言环境显示对应的语言版本。

### 使用示例

```
# 显示从最早到最晚的所有备份月份
./borg-calendar.sh

# 使用指定的仓库路径（本地）
./borg-calendar.sh --borg-repo /path/to/repo

# 使用指定的仓库路径（远程）
./borg-calendar.sh --borg-repo ssh://root@192.168.1.100/borg_repos/huawei_backup

# 显示 2025 年全年日历
./borg-calendar.sh 2025

# 显示 2025 年 7 月
./borg-calendar.sh 2025 7

# 显示今年 7 月
./borg-calendar.sh 7
```

## 输出示例

```
📅 Backup History: 2025-07 to 2025-09
========================================

                              2025

             January |            February |               March 
Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa
       1  2  3  4  5 |                1  2 |                1  2 
 6  7  8  9 10 11 12 | 3  4  5  6  7  8  9 | 3  4  5  6  7  8  9 
13 14 15 16 17 18 19 |10 11 12 13 14 15 16 |10 11 12 13 14 15 16 
20 21 22 23 24 25 26 |17 18 19 20 21 22 23 |17 18 19 20 21 22 23 
27 28 29 30 31       |24 25 26 27 28       |24 25 26 27 28 29 30 
                     |                     |31                   
               April |                 May |                June 
Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa
    1  2  3  4  5  6 |          1  2  3  4 |                   1 
 7  8  9 10 11 12 13 | 5  6  7  8  9 10 11 | 2  3  4  5  6  7  8 
14 15 16 17 18 19 20 |12 13 14 15 16 17 18 | 9 10 11 12 13 14 15 
21 22 23 24 25 26 27 |19 20 21 22 23 24 25 |16 17 18 19 20 21 22 
28 29 30             |26 27 28 29 30 31    |23 24 25 26 27 28 29 
                     |                     |30                   
                July |              August |           September 
Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa
    1  2  3  4  5  6 |             1  2  3 | 1  2  3  4  5  6  7 
 7  8  9 10 11 12 13 | 4  5  6  7  8  9 10 | 8  9 10 11 12 13 14 
14 15 16 17 18 19 20 |11 12 13 14 15 16 17 |15 16 17 18 19 20 21 
21 22 23 24 25 26 27 |18 19 20 21 22 23 24 |22 23 24 25 26 27 28 
28 29 30 31          |25 26 27 28 29 30 31 |29 30                
             October |            November |            December 
Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa |Su Mo Tu We Th Fr Sa
       1  2  3  4  5 |                1  2 | 1  2  3  4  5  6  7 
 6  7  8  9 10 11 12 | 3  4  5  6  7  8  9 | 8  9 10 11 12 13 14 
13 14 15 16 17 18 19 |10 11 12 13 14 15 16 |15 16 17 18 19 20 21 
20 21 22 23 24 25 26 |17 18 19 20 21 22 23 |22 23 24 25 26 27 28 
27 28 29 30 31       |24 25 26 27 28 29 30 |29 30 31
```

有备份的日期将以反转色（背景变白，文字变黑）高亮显示。

![年历显示黑底](images/year-view-black.png)
![年历显示白底](images/year-view-white.png)

## 工作原理

1. 脚本通过 `borg list --format '{start}{NL}'` 命令获取所有归档的创建时间
2. 解析时间信息并按年月日进行分类统计
3. 根据用户输入参数显示相应的日历视图
4. 在日历中高亮显示有备份记录的日期

注意：归档是否存在的判断基于 `{start}` 时间字段，与归档名无关。

## 性能优化

脚本采用了多种性能优化策略：
- 使用全局缓存避免重复执行 `borg list` 命令
- 合并密码检查和数据获取为一次命令执行
- 整个脚本执行周期内最多只执行一次 `borg list` 命令

## 注意事项

1. 确保对 Borg 仓库具有适当的读取权限
2. 对于远程仓库，确保网络连接正常
3. 脚本会缓存所有备份数据以提高性能
4. 如果没有设置 BORG_REPO 环境变量且没有通过命令行参数指定仓库路径，脚本将默认在当前目录下查找 Borg 仓库

## 许可证

请查看 [LICENSE](LICENSE) 文件了解详细信息。