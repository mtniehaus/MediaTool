using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using System.Windows.Threading;

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

            // Get the product list
            Collection<PSObject> list = await wrapper.GetList(null, null, null);

            // Populate the list
            osList.Dispatcher.Invoke(() =>
            {
                osList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Version"].Value))
                {
                    this.osList.Items.Add(l.Properties["Version"].Value);
                }
                osList.SelectedIndex = 0;
                osList.IsEnabled = true;

                folderPath.Text = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
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
            Collection<PSObject> list = await wrapper.GetList(osVersion, null, null);

            // Populate the list
            archList.Dispatcher.Invoke(() =>
            {
                archList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Architecture"].Value))
                {
                    this.archList.Items.Add(l.Properties["Architecture"].Value);
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
            Collection<PSObject> list = await wrapper.GetList(osVersion, architecture, null);

            // Populate the list
            langList.Dispatcher.Invoke(() =>
            {
                langList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Language"].Value))
                {
                    this.langList.Items.Add(l.Properties["Language"].Value);
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
            await Task.Run(async () => await this.InitEdition(os, arch, lang));
        }

        private async Task InitEdition(string osVersion, string architecture, string language)
        {
            // Get the language list
            Collection<PSObject> list = await wrapper.GetList(osVersion, architecture, language);

            // Populate the list
            editionList.Dispatcher.Invoke(() =>
            {
                editionList.Items.Clear();
                foreach (PSObject l in list.OrderBy(p => p.Properties["Edition"].Value))
                {
                    this.editionList.Items.Add(l.Properties["Edition"].Value);
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
            string edition = editionList.SelectedValue.ToString();
            string dest = folderPath.Text;
            bool noP = noPrompt.IsChecked.GetValueOrDefault(false);
            bool recomp = recompress.IsChecked.GetValueOrDefault(false);
            // Disable everything
            generating = true;
            osList.IsEnabled = false;
            archList.IsEnabled = false;
            langList.IsEnabled = false;
            editionList.IsEnabled = false;
            generateButton.IsEnabled = false;
            browseButton.IsEnabled = false;
            noPrompt.IsEnabled = false;
            recompress.IsEnabled = false;
            // Call the async routine to initialize
            await Task.Run(async () => await this.Generate(os, arch, lang, edition, dest, noP, recomp));
            // Re-enable everything
            generating = false;
            osList.IsEnabled = true;
            archList.IsEnabled = true;
            langList.IsEnabled = true;
            editionList.IsEnabled = true;
            generateButton.IsEnabled = true;
            browseButton.IsEnabled = true;
            noPrompt.IsEnabled = true;
            recompress.IsEnabled = true;
            progress.Value = 0;
        }

        private async Task Generate(string osVersion, string architecture, string language, string edition, string dest, bool noPrompt, bool recompress)
        {
            // Invoke
            Collection<PSObject> list = await wrapper.Generate(osVersion, architecture, language, edition, dest, noPrompt, recompress);
        }


        private void browseButton_Click(object sender, RoutedEventArgs e)
        {

        }
    }

    public class MyTraceListener : TraceListener
    {
        private TextBlock output;
        private ScrollViewer viewer;

        public MyTraceListener(TextBlock output, ScrollViewer scroll)
        {
            this.Name = "Trace";
            this.output = output;
            this.viewer = scroll;
        }

        public override void Write(string message)
        {
            output.Dispatcher.Invoke(() =>
            {
                output.Text += message;
                viewer.ScrollToEnd();
            });
        }

        public override void WriteLine(string message)
        {
            Write(message + Environment.NewLine);
        }
    }
}
