using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Linq;
using System.Management.Automation;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Forms;

namespace MediaToolApp
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        ModuleWrapper wrapper;
        bool generating = false;

        public MainWindow()
        {
            InitializeComponent();
        }

        private async void Window_Loaded(object sender, RoutedEventArgs e)
        {
            // Add the trace listener
            TraceListener myTrace = new MyTraceListener(outputBox, scrollBox);
            Trace.Listeners.Add(myTrace);

            // Display an initial message
            Trace.WriteLine("Initializing.");

            // Call the async routine to initialize
            await Task.Run(() => this.Init());
        }

        private async Task Init()
        {
            // Create the wrapper and initialize it.
            wrapper = new ModuleWrapper(this.progress);
            await wrapper.Initialize();

            // Get the USB media list
            Collection<PSObject> usbDrives = await wrapper.GetUSBList();

            // Populate the USB media list
            destDrive.Dispatcher.Invoke(() =>
            {
                destDrive.Items.Clear();
                foreach (PSObject l in usbDrives.OrderBy(p => p.Properties["DriveLetter"].Value))
                {
                    destDrive.Items.Add(l.Properties["DriveLetter"].Value + ":");
                }
                destDrive.SelectedIndex = 0;
                destDrive.IsEnabled = true;

                // While we're here, populate the default ISO path
                folderPath.Text = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            });

            // Get the product list
            Collection<PSObject> list = await wrapper.GetList(null, null, null, null);

            // Populate the media list
            osList.Dispatcher.Invoke(() =>
            {
                osList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Version"].Value))
                {
                    osList.Items.Add(l.Properties["Version"].Value);
                }
                osList.SelectedIndex = 0;
                osList.IsEnabled = true;

            });

            // Enable the needed UI elements, select ISO by default
            createISO.Dispatcher.Invoke(() =>
            {
                createISO.IsEnabled = true;
                createUSB.IsEnabled = true;
                noPrompt.IsEnabled = true;
            });
        }

        private void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            if (generating)
            {
                e.Cancel = true;
                return;
            }
            wrapper.Cleanup();
            wrapper = null;
        }

        private async void osList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (osList.SelectedItem == null) return;

            string os = osList.SelectedValue.ToString();
            // Call the async routine to initialize
            await Task.Run(async () => await this.InitArch(os));
        }

        private async Task InitArch(string osVersion)
        {
            // Get the architecture list
            Collection<PSObject> list = await wrapper.GetList(osVersion, null, null, null);

            // Populate the list
            archList.Dispatcher.Invoke(() =>
            {
                archList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Architecture"].Value))
                {
                    archList.Items.Add(l.Properties["Architecture"].Value);
                }
                archList.SelectedIndex = 0;
                archList.IsEnabled = true;
            });
        }

        private async void archList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (archList.SelectedItem == null) return;

            string os = osList.SelectedValue.ToString();
            string arch = archList.SelectedValue.ToString();
            // Call the async routine to initialize
            await Task.Run(async () => await this.InitLang(os, arch));
        }

        private async Task InitLang(string osVersion, string architecture)
        {
            // Get the language list
            Collection<PSObject> list = await wrapper.GetList(osVersion, architecture, null, null);

            // Populate the list
            langList.Dispatcher.Invoke(() =>
            {
                langList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Language"].Value))
                {
                    langList.Items.Add(l.Properties["Language"].Value);
                }
                langList.SelectedIndex = 0;
                langList.IsEnabled = true;
            });
        }

        private async void langList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (langList.SelectedItem == null) return;

            string os = osList.SelectedValue.ToString();
            string arch = archList.SelectedValue.ToString();
            string lang = langList.SelectedValue.ToString();
            // Call the async routine to initialize
            await Task.Run(async () => await this.InitMedia(os, arch, lang));
        }

        private async Task InitMedia(string osVersion, string architecture, string language)
        {
            // Get the language list
            Collection<PSObject> list = await wrapper.GetList(osVersion, architecture, language, null);

            // Populate the list
            mediaList.Dispatcher.Invoke(() =>
            {
                mediaList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Media"].Value))
                {
                    mediaList.Items.Add(l.Properties["Media"].Value);
                }
                mediaList.SelectedIndex = 0;
                mediaList.IsEnabled = true;
            });
        }

        private async void mediaList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (mediaList.SelectedItem == null) return;

            string os = osList.SelectedValue.ToString();
            string arch = archList.SelectedValue.ToString();
            string lang = langList.SelectedValue.ToString();
            string media = mediaList.SelectedItem.ToString();
            // Call the async routine to initialize
            await Task.Run(async () => await this.InitEdition(os, arch, lang, media));
        }

        private async Task InitEdition(string osVersion, string architecture, string language, string media)
        {
            // Get the language list
            Collection<PSObject> list = await wrapper.GetList(osVersion, architecture, language, media);

            // Populate the list
            editionList.Dispatcher.Invoke(() =>
            {
                editionList.Items.Clear();
                editionList.Items.Add("(All)");
                foreach (PSObject l in list.OrderBy(p => p.Properties["Edition"].Value))
                {
                    editionList.Items.Add(l.Properties["Edition"].Value);
                }
                editionList.SelectedIndex = 0;
                editionList.IsEnabled = true;
                generateButton.IsEnabled = true;
            });
        }

        private async void generateButton_Click(object sender, RoutedEventArgs e)
        {
            string os = osList.SelectedValue.ToString();
            string arch = archList.SelectedValue.ToString();
            string lang = langList.SelectedValue.ToString();
            string media = mediaList.SelectedValue.ToString();
            string edition = editionList.SelectedValue.ToString();
            if (edition == "(All)")
            {
                edition = "";
            }
            string dest = folderPath.Text;
            string drive = (string) destDrive.SelectedValue;
            bool noP = noPrompt.IsChecked.GetValueOrDefault(false);
            bool recomp = recompress.IsChecked.GetValueOrDefault(false);
            // Disable everything
            generating = true;
            osList.IsEnabled = false;
            archList.IsEnabled = false;
            langList.IsEnabled = false;
            mediaList.IsEnabled = false;
            editionList.IsEnabled = false;
            generateButton.IsEnabled = false;
            browseButton.IsEnabled = false;
            noPrompt.IsEnabled = false;
            recompress.IsEnabled = false;
            createISO.IsEnabled = false;
            createUSB.IsEnabled = false;
            mediaList.IsEnabled = false;
            // Call the async routine to create media
            if ((bool)createISO.IsChecked)
            {
                await Task.Run(async () => await this.Generate(os, arch, lang, media, edition, dest, noP, recomp));
            } else
            {
                await Task.Run(async () => await this.Generate(os, arch, lang, media, edition, drive, noP, recomp));
            }
            // Re-enable everything
            generating = false;
            osList.IsEnabled = true;
            archList.IsEnabled = true;
            langList.IsEnabled = true;
            mediaList.IsEnabled = true;
            editionList.IsEnabled = true;
            generateButton.IsEnabled = true;
            browseButton.IsEnabled = true;
            noPrompt.IsEnabled = true;
            recompress.IsEnabled = true;
            createISO.IsEnabled = true;
            createUSB.IsEnabled = true;
            mediaList.IsEnabled = true;
            progress.Value = 0;
        }

        private async Task Generate(string osVersion, string architecture, string language, string media, string edition, string dest, bool noPrompt, bool recompress)
        {
            // Invoke
            Collection<PSObject> list = await wrapper.Generate(osVersion, architecture, language, media, edition, dest, noPrompt, recompress);
        }


        private void browseButton_Click(object sender, RoutedEventArgs e)
        {
            FolderBrowserDialog d = new FolderBrowserDialog();
            if (d.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                folderPath.Text = d.SelectedPath;
            }
        }
    }

    public class MyTraceListener : TraceListener
    {
        private System.Windows.Controls.RichTextBox output;
        private ScrollViewer viewer;

        public MyTraceListener(System.Windows.Controls.RichTextBox output, ScrollViewer scroll)
        {
            Name = "Trace";
            this.output = output;
            viewer = scroll;
        }

        public override void Write(string message)
        {
            output.Dispatcher.Invoke(() =>
            {
                output.AppendText(message);
                viewer.ScrollToEnd();
            });
        }

        public override void WriteLine(string message)
        {
            Write(message.Trim() + "\r");
        }
    }
}
