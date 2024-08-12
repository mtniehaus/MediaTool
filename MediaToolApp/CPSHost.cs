using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MediaToolApp
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Globalization;
    using System.Management.Automation;
    using System.Management.Automation.Host;
    using System.Windows.Controls;

    /// <summary>
    /// A sample implementation of the PSHostUserInterface abstract class for
    /// console applications. Not all members are implemented. Those that are
    /// not implemented throw a NotImplementedException exception. Members that
    /// are implemented include those that map easily to Console APIs.
    /// </summary>
    internal class CPSHostUI : PSHostUserInterface
    {
        ProgressBar p;

        public CPSHostUI(ProgressBar p)
        {
            this.p = p;
        }

        /// <summary>
        /// Gets an instance of the PSRawUserInterface class for this host
        /// application.
        /// </summary>
        public override PSHostRawUserInterface RawUI
        {
            get { return null; }
        }

        /// <summary>
        /// Prompts the user for input. In this example this functionality is not
        /// needed so the method throws a NotImplementException exception.
        /// </summary>
        /// <param name="caption">The caption or title of the prompt.</param>
        /// <param name="message">The text of the prompt.</param>
        /// <param name="descriptions">A collection of FieldDescription objects that
        /// describe each field of the prompt.</param>
        /// <returns>Throws a NotImplementedException exception.</returns>
        public override Dictionary<string, PSObject> Prompt(
                                                            string caption,
                                                            string message,
                                                            System.Collections.ObjectModel.Collection<FieldDescription> descriptions)
        {
            throw new NotImplementedException(
                "The method or operation is not implemented.");
        }

        /// <summary>
        /// Provides a set of choices that enable the user to choose a
        /// single option from a set of options. In this example this
        /// functionality is not needed so the method throws a
        /// NotImplementException exception.
        /// </summary>
        /// <param name="caption">Text that proceeds (a title) the choices.</param>
        /// <param name="message">A message that describes the choice.</param>
        /// <param name="choices">A collection of ChoiceDescription objects that describes
        /// each choice.</param>
        /// <param name="defaultChoice">The index of the label in the Choices parameter
        /// collection. To indicate no default choice, set to -1.</param>
        /// <returns>Throws a NotImplementedException exception.</returns>
        public override int PromptForChoice(string caption, string message, System.Collections.ObjectModel.Collection<ChoiceDescription> choices, int defaultChoice)
        {
            throw new NotImplementedException("The method or operation is not implemented.");
        }

        /// <summary>
        /// Prompts the user for credentials with a specified prompt window caption,
        /// prompt message, user name, and target name. In this example this
        /// functionality is not needed so the method throws a
        /// NotImplementException exception.
        /// </summary>
        /// <param name="caption">The caption for the message window.</param>
        /// <param name="message">The text of the message.</param>
        /// <param name="userName">The user name whose credential is to be prompted for.</param>
        /// <param name="targetName">The name of the target for which the credential is collected.</param>
        /// <returns>Throws a NotImplementedException exception.</returns>
        public override PSCredential PromptForCredential(
                                                            string caption,
                                                            string message,
                                                            string userName,
                                                            string targetName)
        {
            throw new NotImplementedException("The method or operation is not implemented.");
        }

        /// <summary>
        /// Prompts the user for credentials by using a specified prompt window caption,
        /// prompt message, user name and target name, credential types allowed to be
        /// returned, and UI behavior options. In this example this functionality
        /// is not needed so the method throws a NotImplementException exception.
        /// </summary>
        /// <param name="caption">The caption for the message window.</param>
        /// <param name="message">The text of the message.</param>
        /// <param name="userName">The user name whose credential is to be prompted for.</param>
        /// <param name="targetName">The name of the target for which the credential is collected.</param>
        /// <param name="allowedCredentialTypes">A PSCredentialTypes constant that
        /// identifies the type of credentials that can be returned.</param>
        /// <param name="options">A PSCredentialUIOptions constant that identifies the UI
        /// behavior when it gathers the credentials.</param>
        /// <returns>Throws a NotImplementedException exception.</returns>
        public override PSCredential PromptForCredential(
                                                            string caption,
                                                            string message,
                                                            string userName,
                                                            string targetName,
                                                            PSCredentialTypes allowedCredentialTypes,
                                                            PSCredentialUIOptions options)
        {
            throw new NotImplementedException("The method or operation is not implemented.");
        }

        /// <summary>
        /// Reads characters that are entered by the user until a newline
        /// (carriage return) is encountered.
        /// </summary>
        /// <returns>The characters that are entered by the user.</returns>
        public override string ReadLine()
        {
            throw new NotImplementedException("The method or operation is not implemented.");
        }

        /// <summary>
        /// Reads characters entered by the user until a newline (carriage return)
        /// is encountered and returns the characters as a secure string. In this
        /// example this functionality is not needed so the method throws a
        /// NotImplementException exception.
        /// </summary>
        /// <returns>Throws a NotImplemented exception.</returns>
        public override System.Security.SecureString ReadLineAsSecureString()
        {
            throw new NotImplementedException("The method or operation is not implemented.");
        }

        /// <summary>
        /// Writes characters to the output display of the host.
        /// </summary>
        /// <param name="value">The characters to be written.</param>
        public override void Write(string value)
        {
            Trace.Write(value);
        }

        /// <summary>
        /// Writes characters to the output display of the host and specifies the
        /// foreground and background colors of the characters. This implementation
        /// ignores the colors.
        /// </summary>
        /// <param name="foregroundColor">The color of the characters.</param>
        /// <param name="backgroundColor">The background color to use.</param>
        /// <param name="value">The characters to be written.</param>
        public override void Write(
                                    ConsoleColor foregroundColor,
                                    ConsoleColor backgroundColor,
                                    string value)
        {
            // Colors are ignored.
            Trace.Write(value);
        }

        /// <summary>
        /// Writes a debug message to the output display of the host.
        /// </summary>
        /// <param name="message">The debug message that is displayed.</param>
        public override void WriteDebugLine(string message)
        {
            Trace.WriteLine(message);
        }

        /// <summary>
        /// Writes an error message to the output display of the host.
        /// </summary>
        /// <param name="value">The error message that is displayed.</param>
        public override void WriteErrorLine(string value)
        {
            Trace.WriteLine(value);
        }

        /// <summary>
        /// Writes a newline character (carriage return)
        /// to the output display of the host.
        /// </summary>
        public override void WriteLine()
        {
            Trace.WriteLine("");
        }

        /// <summary>
        /// Writes a line of characters to the output display of the host
        /// and appends a newline character(carriage return).
        /// </summary>
        /// <param name="value">The line to be written.</param>
        public override void WriteLine(string value)
        {
            Trace.WriteLine(value);
        }

        /// <summary>
        /// Writes a line of characters to the output display of the host
        /// with foreground and background colors and appends a newline (carriage return).
        /// </summary>
        /// <param name="foregroundColor">The foreground color of the display. </param>
        /// <param name="backgroundColor">The background color of the display. </param>
        /// <param name="value">The line to be written.</param>
        public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
        {
            // Write to the output stream, ignore the colors
            Trace.WriteLine(value);
        }

        /// <summary>
        /// Writes a progress report to the output display of the host.
        /// </summary>
        /// <param name="sourceId">Unique identifier of the source of the record. </param>
        /// <param name="record">A ProgressReport object.</param>
        public override void WriteProgress(long sourceId, ProgressRecord record)
        {
            p.Dispatcher.Invoke(() =>
            {
                p.Value = record.PercentComplete;
            });
        }

        /// <summary>
        /// Writes a verbose message to the output display of the host.
        /// </summary>
        /// <param name="message">The verbose message that is displayed.</param>
        public override void WriteVerboseLine(string message)
        {
            Trace.WriteLine(message);
        }

        /// <summary>
        /// Writes a warning message to the output display of the host.
        /// </summary>
        /// <param name="message">The warning message that is displayed.</param>
        public override void WriteWarningLine(string message)
        {
            Trace.WriteLine(message);
        }
    }

    /// <summary>
    /// This is a sample implementation of the PSHost abstract class for
    /// console applications. Not all members are implemented. Those that
    /// are not implemented throw a NotImplementedException exception or
    /// return nothing.
    /// </summary>
    internal class CPSHost : PSHost
    {
        /// <summary>
        /// A reference to the implementation of the PSHostUserInterface
        /// class for this application.
        /// </summary>
        private readonly CPSHostUI hostUI;

        // Constructor
        public CPSHost(ProgressBar p)
        {
            hostUI = new CPSHostUI(p);
        }

        /// <summary>
        /// The culture information of the thread that created
        /// this object.
        /// </summary>
        private readonly CultureInfo originalCultureInfo =
            System.Threading.Thread.CurrentThread.CurrentCulture;

        /// <summary>
        /// The UI culture information of the thread that created
        /// this object.
        /// </summary>
        private readonly CultureInfo originalUICultureInfo =
            System.Threading.Thread.CurrentThread.CurrentUICulture;

        /// <summary>
        /// The identifier of this PSHost implementation.
        /// </summary>
        private readonly Guid myId = Guid.NewGuid();

        /// <summary>
        /// Return the culture information to use. This implementation
        /// returns a snapshot of the culture information of the thread
        /// that created this object.
        /// </summary>
        public override System.Globalization.CultureInfo CurrentCulture
        {
            get { return this.originalCultureInfo; }
        }

        /// <summary>
        /// Return the UI culture information to use. This implementation
        /// returns a snapshot of the UI culture information of the thread
        /// that created this object.
        /// </summary>
        public override System.Globalization.CultureInfo CurrentUICulture
        {
            get { return this.originalUICultureInfo; }
        }

        /// <summary>
        /// This implementation always returns the GUID allocated at
        /// instantiation time.
        /// </summary>
        public override Guid InstanceId
        {
            get { return this.myId; }
        }

        /// <summary>
        /// Return a string that contains the name of the host implementation.
        /// Keep in mind that this string may be used by script writers to
        /// identify when your host is being used.
        /// </summary>
        public override string Name
        {
            get { return "MediaToolApp.PowerShellHost"; }
        }

        /// <summary>
        /// Gets an instance of the implementation of the PSHostUserInterface
        /// class for this application. This instance is allocated once at startup time
        /// and returned every time thereafter.
        /// </summary>
        public override PSHostUserInterface UI
        {
            get { return this.hostUI; }
        }

        /// <summary>
        /// Return the version object for this application. Typically this
        /// should match the version resource in the application.
        /// </summary>
        public override Version Version
        {
            get { return new Version(1, 0, 0, 0); }
        }

        /// <summary>
        /// Not implemented by this example class. The call fails with
        /// a NotImplementedException exception.
        /// </summary>
        public override void EnterNestedPrompt()
        {
            throw new NotImplementedException(
                "The method or operation is not implemented.");
        }

        /// <summary>
        /// Not implemented by this example class. The call fails
        /// with a NotImplementedException exception.
        /// </summary>
        public override void ExitNestedPrompt()
        {
            throw new NotImplementedException(
                "The method or operation is not implemented.");
        }

        /// <summary>
        /// This API is called before an external application process is
        /// started. Typically it is used to save state so the parent can
        /// restore state that has been modified by a child process (after
        /// the child exits). In this example, this functionality is not
        /// needed so the method returns nothing.
        /// </summary>
        public override void NotifyBeginApplication()
        {
            return;
        }

        /// <summary>
        /// This API is called after an external application process finishes.
        /// Typically it is used to restore state that a child process may
        /// have altered. In this example, this functionality is not
        /// needed so the method returns nothing.
        /// </summary>
        public override void NotifyEndApplication()
        {
            return;
        }

        /// <summary>
        /// Indicate to the host application that exit has
        /// been requested. Pass the exit code that the host
        /// application should use when exiting the process.
        /// </summary>
        /// <param name="exitCode">The exit code to use.</param>
        public override void SetShouldExit(int exitCode)
        {

        }
    }
}
