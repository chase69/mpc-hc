/*
 * (C) 2015 see Authors.txt
 *
 * This file is part of MPC-HC.
 *
 * MPC-HC is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * MPC-HC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "stdafx.h"
#include <DbgHelp.h>
#include "CrashReporter.h"
#include "VersionInfo.h"
#include "mpc-hc_config.h"
#include "DoctorDump/CrashRpt.h"

#ifndef _DEBUG
namespace CrashReporter
{
    static crash_rpt::CrashRpt& GetInstance()
    {
        static crash_rpt::CrashRpt crashReporter(L"CrashReporter\\crashrpt.dll");
        return crashReporter;
    }
}
#endif

void CrashReporter::Enable()
{
#ifndef _DEBUG
    static crash_rpt::ApplicationInfo appInfo = {
        sizeof(appInfo),
        "22a47693-1918-4edb-bfac-41556c1c6b6a",
        "mpc-hc",
        L"MPC-HC",
        L"MPC-HC Team",
        {
            USHORT(VersionInfo::GetMajorNumber()),
            USHORT(VersionInfo::GetMinorNumber()),
            USHORT(VersionInfo::GetPatchNumber()),
            USHORT(VersionInfo::GetRevisionNumber()),
        },
        0,
        nullptr
    };

    const MINIDUMP_TYPE dumpType = MINIDUMP_TYPE(
#if ENABLE_FULLDUMP
                                       MiniDumpWithFullMemory |
                                       MiniDumpWithTokenInformation |
#else
                                       MiniDumpWithIndirectlyReferencedMemory |
                                       MiniDumpWithDataSegs |
#endif // ENABLE_FULLDUMP
                                       MiniDumpWithHandleData |
                                       MiniDumpWithThreadInfo |
                                       MiniDumpWithProcessThreadData |
                                       MiniDumpWithFullMemoryInfo |
                                       MiniDumpWithUnloadedModules |
                                       MiniDumpIgnoreInaccessibleMemory
                                   );

    static crash_rpt::HandlerSettings handlerSettings = {
        sizeof(handlerSettings),
        FALSE,      // Don't keep the dumps
        FALSE,      // Don't open the problem page in the browser
        TRUE,       // Use WER
        0,          // Anonymous submitter
        FALSE,      // Ask before sending additional info
        TRUE,       // Override the "full" dump settings
        dumpType,   // "Full" dump custom settings
        nullptr,    // No lang file (for now)
        nullptr,    // Default path for SendRpt
        nullptr,    // Default path for DbgHelp
        nullptr,    // No callback function (yet)
        nullptr     // No user defined parameter for the callback function
    };

    if (!GetInstance().IsCrashHandlingEnabled()) {
        GetInstance().InitCrashRpt(&appInfo, &handlerSettings);
    }
#endif
};
