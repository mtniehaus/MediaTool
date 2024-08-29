using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading.Tasks;
using System.Windows.Controls;

namespace MediaToolApp
{
    internal class ModuleWrapper
    {
        private RunspacePool pool;

        public ModuleWrapper(ProgressBar p) {
            // Determine the location of modules
            string modulePath;
            string myPath = AppDomain.CurrentDomain.BaseDirectory;
            if (Directory.Exists($"{myPath}\\Modules"))
            {
                modulePath = $"{myPath}\\Modules";
            } else
            {
                // Hard code while debugging
                modulePath = Directory.GetParent(myPath).Parent.Parent.Parent.FullName + @"\Modules";
            }

            // Create the PSHost
            CPSHost host = new CPSHost(p);

            // Create the runspace pool with the host
            InitialSessionState iss = InitialSessionState.CreateDefault();
            iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
            iss.ImportPSModule(new String[] { $"{modulePath}\\MediaTool" });
            pool = RunspaceFactory.CreateRunspacePool(1, 1, iss, host);
            pool.Open();
        }

        public void Cleanup()
        {
            pool.Close();
            pool.Dispose();
        }

        public async Task<Collection<PSObject>> Initialize()
        {
            try
            {
                // First initialize
                PSCommand initialize = new PSCommand();
                Trace.WriteLine("Downloading manifests.");
                initialize.AddCommand("Initialize-MediaTool");

                return RunCommandAsync(initialize).Result;
            }
            catch (Exception ex)
            {
                Trace.WriteLine("Unhandled exception: " + ex.ToString());
            }
            return null;
        }

        public async Task<Collection<PSObject>> GetList(string product, string architecture, string language, string media)
        {
            try
            {
                PSCommand list = new PSCommand();
                list.AddCommand("Get-MediaToolList");
                if (product != null)
                {
                    list.AddParameter("Product", product);
                }
                if (architecture != null)
                {
                    list.AddParameter("Architecture", architecture);
                }
                if (language != null)
                {
                    list.AddParameter("Language", language);
                }
                if (media != null)
                {
                    list.AddParameter("Media", media);
                }

                Task<Collection<PSObject>> t = RunCommandAsync(list);
                return t.Result;
            }
            catch (Exception ex)
            {
                Trace.WriteLine("Unhandled exception: " + ex.ToString());
            }
            return null;
        }

        public async Task<Collection<PSObject>> GetUSBList()
        {
            try
            {
                PSCommand list = new PSCommand();
                list.AddCommand("Get-MediaToolUSB");

                Task<Collection<PSObject>> t = RunCommandAsync(list);
                return t.Result;
            }
            catch (Exception ex)
            {
                Trace.WriteLine("Unhandled exception: " + ex.ToString());
            }
            return null;
        }

        public async Task<Collection<PSObject>> Generate(string product, string architecture, string language, string media, string edition, string dest, bool noPrompt, bool recompress)
        {
            try
            {
                PSCommand list = new PSCommand();
                list.AddCommand("New-MediaToolMedia")
                    .AddParameter("Product", product)
                    .AddParameter("Architecture", architecture)
                    .AddParameter("Language", language)
                    .AddParameter("Media", media)
                    .AddParameter("Destination", dest);
                if (noPrompt)
                {
                    list.AddParameter("NoPrompt");
                }
                if (recompress)
                {
                    list.AddParameter("Recompress");
                }
                if (!String.IsNullOrEmpty(edition))
                {
                    list.AddParameter("Edition", edition);
                }
                list.AddParameter("Verbose");

                Task<Collection<PSObject>> t = RunCommandAsync(list);
                return t.Result;
            }
            catch (Exception ex)
            {
                Trace.WriteLine("Unhandled exception: " + ex.ToString());
            }
            return null;
        }

        public Task<Collection<PSObject>> RunCommandAsync(PSCommand command)
        {
            return Task.Run(() =>
            {
                using (PowerShell ps = PowerShell.Create())
                {
                    ps.Commands = command;
                    ps.RunspacePool = pool;
                    return ps.Invoke<PSObject>();
                }
            });
        }
    }

}
