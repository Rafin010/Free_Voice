using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace FreeVoiceSetup
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupForm());
        }
    }

    internal sealed class SetupForm : Form
    {
        private const string AppName = "FreeVoice";
        private const string AppVersion = "1.0.0";
        private const string ResourceName = "FreeVoice.payload.zip";

        private readonly Panel _headerPanel;
        private readonly Label _titleLabel;
        private readonly Label _subtitleLabel;
        private readonly Panel _contentPanel;
        private readonly Panel _footerPanel;

        private readonly Button _backButton;
        private readonly Button _nextButton;
        private readonly Button _cancelButton;

        // Page 1: Options
        private readonly Panel _pageOptions;
        private readonly TextBox _pathBox;
        private readonly CheckBox _chkDesktop;
        private readonly CheckBox _chkStartup;
        private readonly CheckBox _chkRunSetup;

        // Page 2: Progress
        private readonly Panel _pageProgress;
        private readonly Label _progressLabel;
        private readonly ProgressBar _progressBar;

        // Page 3: Finish
        private readonly Panel _pageFinish;
        private readonly CheckBox _chkLaunchNow;

        private int _step = 0;

        public SetupForm()
        {
            Text = AppName + " Setup";
            Size = new Size(520, 380);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.White;
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            try
            {
                Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch { }

            // Header
            _headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 68,
                BackColor = Color.White
            };
            _headerPanel.Paint += (s, e) =>
            {
                using (var pen = new Pen(Color.FromArgb(229, 231, 235)))
                {
                    e.Graphics.DrawLine(pen, 0, _headerPanel.Height - 1, _headerPanel.Width, _headerPanel.Height - 1);
                }
            };

            _titleLabel = new Label
            {
                Text = "Install FreeVoice",
                Font = new Font("Segoe UI", 12.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(17, 24, 39),
                Location = new Point(22, 12),
                AutoSize = true
            };

            _subtitleLabel = new Label
            {
                Text = "Voice typing for Windows (AutoHotkey v2)",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(75, 85, 99),
                Location = new Point(22, 38),
                AutoSize = true
            };

            _headerPanel.Controls.Add(_titleLabel);
            _headerPanel.Controls.Add(_subtitleLabel);

            // Footer
            _footerPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 56,
                BackColor = Color.FromArgb(249, 250, 251)
            };
            _footerPanel.Paint += (s, e) =>
            {
                using (var pen = new Pen(Color.FromArgb(229, 231, 235)))
                {
                    e.Graphics.DrawLine(pen, 0, 0, _footerPanel.Width, 0);
                }
            };

            _backButton = new Button
            {
                Text = "Back",
                Size = new Size(84, 30),
                Location = new Point(220, 13),
                Visible = false
            };

            _nextButton = new Button
            {
                Text = "Install",
                Size = new Size(92, 30),
                Location = new Point(310, 13)
            };
            _nextButton.Click += OnNextClicked;

            _cancelButton = new Button
            {
                Text = "Cancel",
                Size = new Size(84, 30),
                Location = new Point(408, 13)
            };
            _cancelButton.Click += (s, e) => Close();

            _footerPanel.Controls.Add(_backButton);
            _footerPanel.Controls.Add(_nextButton);
            _footerPanel.Controls.Add(_cancelButton);

            // Content container
            _contentPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                Padding = new Padding(22)
            };

            // Page 1: Options
            _pageOptions = new Panel { Dock = DockStyle.Fill, BackColor = Color.White };
            var lblIntro = new Label
            {
                Text = "Choose installation folder and shortcuts. Press ` once anywhere in Windows to start Listening, and press ` again to insert text.",
                Location = new Point(0, 6),
                Size = new Size(456, 40),
                ForeColor = Color.FromArgb(55, 65, 81)
            };

            var lblFolder = new Label
            {
                Text = "Destination folder:",
                Location = new Point(0, 56),
                AutoSize = true,
                ForeColor = Color.FromArgb(17, 24, 39)
            };

            string defaultDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                AppName);

            _pathBox = new TextBox
            {
                Text = defaultDir,
                Location = new Point(0, 78),
                Size = new Size(368, 25)
            };

            var btnBrowse = new Button
            {
                Text = "Browse...",
                Location = new Point(376, 77),
                Size = new Size(80, 26)
            };
            btnBrowse.Click += (s, e) =>
            {
                using (var dlg = new FolderBrowserDialog())
                {
                    dlg.SelectedPath = _pathBox.Text;
                    if (dlg.ShowDialog() == DialogResult.OK)
                    {
                        _pathBox.Text = Path.Combine(dlg.SelectedPath, AppName);
                    }
                }
            };

            _chkDesktop = new CheckBox
            {
                Text = "Create a desktop shortcut",
                Checked = true,
                Location = new Point(0, 120),
                AutoSize = true
            };

            _chkStartup = new CheckBox
            {
                Text = "Launch FreeVoice at Windows startup",
                Checked = false,
                Location = new Point(0, 146),
                AutoSize = true
            };

            _chkRunSetup = new CheckBox
            {
                Text = "Install Python & AutoHotkey v2 dependencies after copying files",
                Checked = true,
                Location = new Point(0, 172),
                AutoSize = true
            };

            _pageOptions.Controls.AddRange(new Control[]
            {
                lblIntro, lblFolder, _pathBox, btnBrowse, _chkDesktop, _chkStartup, _chkRunSetup
            });

            // Page 2: Progress
            _pageProgress = new Panel { Dock = DockStyle.Fill, BackColor = Color.White, Visible = false };
            _progressLabel = new Label
            {
                Text = "Preparing installation...",
                Location = new Point(0, 42),
                Size = new Size(456, 24),
                ForeColor = Color.FromArgb(17, 24, 39)
            };
            _progressBar = new ProgressBar
            {
                Location = new Point(0, 72),
                Size = new Size(456, 22),
                Minimum = 0,
                Maximum = 100
            };
            _pageProgress.Controls.Add(_progressLabel);
            _pageProgress.Controls.Add(_progressBar);

            // Page 3: Finish
            _pageFinish = new Panel { Dock = DockStyle.Fill, BackColor = Color.White, Visible = false };
            var lblDone = new Label
            {
                Text = "FreeVoice has been installed on your computer.\n\nPress ` (backtick / tilde key) once to start Listening, and press ` again to type at your cursor.",
                Location = new Point(0, 16),
                Size = new Size(456, 76),
                ForeColor = Color.FromArgb(17, 24, 39)
            };
            _chkLaunchNow = new CheckBox
            {
                Text = "Launch FreeVoice now",
                Checked = true,
                Location = new Point(0, 108),
                AutoSize = true
            };
            _pageFinish.Controls.Add(lblDone);
            _pageFinish.Controls.Add(_chkLaunchNow);

            _contentPanel.Controls.Add(_pageOptions);
            _contentPanel.Controls.Add(_pageProgress);
            _contentPanel.Controls.Add(_pageFinish);

            Controls.Add(_contentPanel);
            Controls.Add(_footerPanel);
            Controls.Add(_headerPanel);
        }

        private async void OnNextClicked(object sender, EventArgs e)
        {
            if (_step == 0)
            {
                string installDir = _pathBox.Text.Trim();
                if (string.IsNullOrEmpty(installDir))
                {
                    MessageBox.Show("Please choose a destination folder.", AppName + " Setup",
                        MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }

                _step = 1;
                _pageOptions.Visible = false;
                _pageProgress.Visible = true;
                _nextButton.Enabled = false;
                _cancelButton.Enabled = false;
                _titleLabel.Text = "Installing FreeVoice";
                _subtitleLabel.Text = "Please wait while files are installed...";

                try
                {
                    await Task.Run(() => PerformInstall(
                        installDir,
                        _chkDesktop.Checked,
                        _chkStartup.Checked));

                    if (_chkRunSetup.Checked)
                    {
                        SetProgress("Installing dependencies (Python & AutoHotkey v2)...", 85);
                        string setupBat = Path.Combine(installDir, "setup.bat");
                        if (File.Exists(setupBat))
                        {
                            var psi = new ProcessStartInfo("cmd.exe", "/c \"" + setupBat + "\"")
                            {
                                WorkingDirectory = installDir,
                                UseShellExecute = true
                            };
                            using (var proc = Process.Start(psi))
                            {
                                if (proc != null)
                                {
                                    await Task.Run(() => proc.WaitForExit());
                                }
                            }
                        }
                    }

                    SetProgress("Completed.", 100);
                    _step = 2;
                    _pageProgress.Visible = false;
                    _pageFinish.Visible = true;
                    _titleLabel.Text = "Installation Complete";
                    _subtitleLabel.Text = "FreeVoice v" + AppVersion + " is ready to use.";
                    _nextButton.Text = "Finish";
                    _nextButton.Enabled = true;
                    _cancelButton.Visible = false;
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Installation failed: " + ex.Message, AppName + " Setup",
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    _step = 0;
                    _pageProgress.Visible = false;
                    _pageOptions.Visible = true;
                    _nextButton.Enabled = true;
                    _cancelButton.Enabled = true;
                }
            }
            else if (_step == 2)
            {
                if (_chkLaunchNow.Checked)
                {
                    string installDir = _pathBox.Text.Trim();
                    string launcher = File.Exists(Path.Combine(installDir, "FreeVoice.exe"))
                        ? Path.Combine(installDir, "FreeVoice.exe")
                        : Path.Combine(installDir, "launch.bat");
                    if (File.Exists(launcher))
                    {
                        Process.Start(new ProcessStartInfo(launcher)
                        {
                            WorkingDirectory = installDir,
                            UseShellExecute = true
                        });
                    }
                }
                Close();
            }
        }

        private void SetProgress(string message, int percent)
        {
            if (InvokeRequired)
            {
                Invoke(new Action(() => SetProgress(message, percent)));
                return;
            }
            _progressLabel.Text = message;
            _progressBar.Value = Math.Max(0, Math.Min(100, percent));
        }

        private void PerformInstall(string installDir, bool createDesktop, bool addStartup)
        {
            SetProgress("Creating installation directory...", 10);
            Directory.CreateDirectory(installDir);

            SetProgress("Extracting FreeVoice files...", 30);
            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream stream = asm.GetManifestResourceStream(ResourceName))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("Embedded payload missing.");
                }
                using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
                {
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        if (string.IsNullOrEmpty(entry.Name))
                        {
                            continue;
                        }
                        string destPath = Path.Combine(installDir, entry.FullName);
                        string destFolder = Path.GetDirectoryName(destPath);
                        if (!string.IsNullOrEmpty(destFolder))
                        {
                            Directory.CreateDirectory(destFolder);
                        }
                        // Preserve existing user config.ini on upgrades
                        if (entry.Name.Equals("config.ini", StringComparison.OrdinalIgnoreCase) && File.Exists(destPath))
                        {
                            continue;
                        }
                        using (Stream entryStream = entry.Open())
                        using (FileStream fs = new FileStream(destPath, FileMode.Create, FileAccess.Write))
                        {
                            entryStream.CopyTo(fs);
                        }
                    }
                }
            }

            SetProgress("Creating uninstaller...", 55);
            string startMenuDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Programs),
                AppName);
            Directory.CreateDirectory(startMenuDir);

            string desktopShortcut = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                AppName + ".lnk");
            string uninstallBat = Path.Combine(installDir, "Uninstall.bat");

            string batContent =
                "@echo off\r\n" +
                "taskkill /F /IM FreeVoice.exe >nul 2>&1\r\n" +
                "taskkill /F /IM AutoHotkey64.exe >nul 2>&1\r\n" +
                "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\" /v \"FreeVoice\" /f >nul 2>&1\r\n" +
                "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\FreeVoice\" /f >nul 2>&1\r\n" +
                "if exist \"" + desktopShortcut + "\" del /F /Q \"" + desktopShortcut + "\"\r\n" +
                "if exist \"" + startMenuDir + "\" rmdir /S /Q \"" + startMenuDir + "\"\r\n" +
                "echo FreeVoice has been uninstalled.\r\n" +
                "timeout /t 2 /nobreak >nul\r\n" +
                "start \"\" /b cmd /c \"timeout /t 1 /nobreak >nul & rmdir /S /Q \"\"" + installDir + "\"\"\"\r\n";
            File.WriteAllText(uninstallBat, batContent);

            SetProgress("Creating shortcuts...", 70);
            string targetExe = File.Exists(Path.Combine(installDir, "FreeVoice.exe"))
                ? Path.Combine(installDir, "FreeVoice.exe")
                : Path.Combine(installDir, "launch.bat");
            string iconPath = Path.Combine(installDir, "icon.ico");

            CreateShortcut(Path.Combine(startMenuDir, AppName + ".lnk"), targetExe, installDir, iconPath, "FreeVoice Voice Typing");
            CreateShortcut(Path.Combine(startMenuDir, "Uninstall " + AppName + ".lnk"), uninstallBat, installDir, iconPath, "Uninstall FreeVoice");

            if (createDesktop)
            {
                CreateShortcut(desktopShortcut, targetExe, installDir, iconPath, "FreeVoice Voice Typing");
            }

            if (addStartup)
            {
                using (RegistryKey runKey = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
                {
                    if (runKey != null)
                    {
                        runKey.SetValue(AppName, "\"" + targetExe + "\"");
                    }
                }
            }

            using (RegistryKey uninstKey = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\FreeVoice"))
            {
                if (uninstKey != null)
                {
                    uninstKey.SetValue("DisplayName", AppName);
                    uninstKey.SetValue("DisplayVersion", AppVersion);
                    uninstKey.SetValue("Publisher", AppName);
                    uninstKey.SetValue("InstallLocation", installDir);
                    uninstKey.SetValue("DisplayIcon", iconPath);
                    uninstKey.SetValue("UninstallString", "\"" + uninstallBat + "\"");
                    uninstKey.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    uninstKey.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                }
            }

            SetProgress("Files installed.", 80);
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string iconPath, string description)
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null)
            {
                return;
            }
            object shell = Activator.CreateInstance(shellType);
            object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
            Type scType = shortcut.GetType();
            scType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath });
            scType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workingDir });
            scType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
            if (File.Exists(iconPath))
            {
                scType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { iconPath });
            }
            scType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
        }
    }
}
