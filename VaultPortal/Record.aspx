<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/Site.master"
    CodeFile="Record.aspx.cs" Inherits="VaultPortal.RecordPage" %>

<asp:Content ContentPlaceHolderID="Head" runat="server">
<script>
document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(".section-header").forEach(function (h) {
        h.addEventListener("click", function () {
            h.parentNode.classList.toggle("open");
        });
    });
});
</script>
</asp:Content>

<asp:Content ContentPlaceHolderID="Body" runat="server">
    <div class="detailwrap">

        <div class="rec-head">
            <div>
                <div class="rec-name"><asp:Literal ID="litName" runat="server" /></div>
                <div class="rec-sub"><asp:Literal ID="litSub" runat="server" /></div>
            </div>
            <div style="text-align:right;">
                <div class="rec-no"><asp:Literal ID="litFileNo" runat="server" /></div>
                <div style="margin-top:6px;"><asp:Literal ID="litStamp" runat="server" /></div>
            </div>
        </div>

        <asp:Panel ID="pnlSaved" runat="server" Visible="false" CssClass="savednote">
            Changes saved. The edit was recorded in the vault access log.
        </asp:Panel>
        <asp:Panel ID="pnlError" runat="server" Visible="false" CssClass="errnote">
            <asp:Literal ID="litError" runat="server" />
        </asp:Panel>

        <div id="secIdentity" runat="server" class="section">
            <div class="section-header">FILE IDENTITY</div>
            <div class="section-body">
            <div class="hint" style="margin:-2px 0 10px;">Start/End dates are reliable from 2022 onward; for earlier history see Modified (old VDB) under Provenance.</div>
                <div class="fgrid">
                <div class="f">
                    <label>Family name</label>
                    <asp:TextBox ID="f_FamilyName" runat="server" />
                </div>
                <div class="f">
                    <label>Family name (alt.)</label>
                    <asp:TextBox ID="f_FamilyNameAlt" runat="server" />
                </div>
                <div class="f f-num">
                    <label>File number</label>
                    <asp:TextBox ID="f_FileNumber" runat="server" />
                </div>
                <div class="f">
                    <label>File type</label>
                    <asp:TextBox ID="f_FileType" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Start date</label>
                    <asp:TextBox ID="f_StartDate" runat="server" />
                </div>
                <div class="f f-num">
                    <label>End date</label>
                    <asp:TextBox ID="f_EndDate" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secPaper" runat="server" class="section">
            <div class="section-header">PERMANENT PAPER FILE</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_PermPaperFile" runat="server" />
                    <label>Permanent paper file exists</label>
                </div>
                <div class="f f-num">
                    <label>Recall box barcode</label>
                    <asp:TextBox ID="f_RecallBoxBarCode" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Box number</label>
                    <asp:TextBox ID="f_PermPaperBoxNumber" runat="server" />
                </div>
                <div class="f">
                    <label>Location</label>
                    <asp:TextBox ID="f_PermPaperLocation" runat="server" />
                </div>
                <div class="f">
                    <label>Location (old VDB)</label>
                    <asp:TextBox ID="f_PermPaperLocationOld" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_PermPaperSignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_PermPaperSignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_PermPaperSignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_PermPaperSignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secAudio" runat="server" class="section">
            <div class="section-header">AUDIO TAPE</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_AudioTape" runat="server" />
                    <label>Audio tape exists</label>
                </div>
                <div class="f f-num">
                    <label>Barcode</label>
                    <asp:TextBox ID="f_AudioBarCode" runat="server" />
                </div>
                <div class="f">
                    <label>Location</label>
                    <asp:TextBox ID="f_AudioLocation" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_AudioSignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_AudioSignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_AudioSignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_AudioSignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secVideo" runat="server" class="section">
            <div class="section-header">VIDEO TAPE</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_VideoTape" runat="server" />
                    <label>Video tape exists</label>
                </div>
                <div class="f f-num">
                    <label>Barcode</label>
                    <asp:TextBox ID="f_VideoBarCode" runat="server" />
                </div>
                <div class="f">
                    <label>Location</label>
                    <asp:TextBox ID="f_VideoLocation" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_VideoSignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_VideoSignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_VideoSignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_VideoSignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secCd" runat="server" class="section">
            <div class="section-header">CD / DVD</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_CdDvd" runat="server" />
                    <label>CD/DVD exists</label>
                </div>
                <div class="f f-num">
                    <label>Barcode</label>
                    <asp:TextBox ID="f_CdDvdBarCode" runat="server" />
                </div>
                <div class="f">
                    <label>Location</label>
                    <asp:TextBox ID="f_CdDvdLocation" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_CdDvdSignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_CdDvdSignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_CdDvdSignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_CdDvdSignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secFiche" runat="server" class="section">
            <div class="section-header">MICROFICHE</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_Microfiche" runat="server" />
                    <label>Microfiche exists</label>
                </div>
                <div class="f f-num">
                    <label>Barcode</label>
                    <asp:TextBox ID="f_MicroficheBarCode" runat="server" />
                </div>
                <div class="f">
                    <label>Location</label>
                    <asp:TextBox ID="f_MicroficheLocation" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_MicroficheSignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_MicroficheSignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_MicroficheSignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_MicroficheSignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secWF" runat="server" class="section">
            <div class="section-header">WORKING FILE</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_WorkingFileCreated" runat="server" />
                    <label>Working file created</label>
                </div>
                <div class="f f-num">
                    <label>Assigned date</label>
                    <asp:TextBox ID="f_WorkingFileAssignedDate" runat="server" />
                </div>
                <div class="f">
                    <label>Assigned to</label>
                    <asp:TextBox ID="f_WorkingFileAssignedTo" runat="server" />
                </div>
                <div class="f">
                    <label>Assigned to (email)</label>
                    <asp:TextBox ID="f_WorkingFileAssignedToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Assigned to (old VDB)</label>
                    <asp:TextBox ID="f_WorkingFileAssignedToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secWF2" runat="server" class="section">
            <div class="section-header">WORKING FILE 2</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_WF2Created" runat="server" />
                    <label>WF2 created</label>
                </div>
                <div class="f">
                    <label>Type</label>
                    <asp:TextBox ID="f_WF2Type" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_WF2SignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_WF2SignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_WF2SignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_WF2SignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secWF3" runat="server" class="section">
            <div class="section-header">WORKING FILE 3</div>
            <div class="section-body">
                <div class="fgrid">
                <div class="f f-check">
                    <asp:CheckBox ID="c_WF3Created" runat="server" />
                    <label>WF3 created</label>
                </div>
                <div class="f">
                    <label>Type</label>
                    <asp:TextBox ID="f_WF3Type" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Signed out date</label>
                    <asp:TextBox ID="f_WF3SignedOutDate" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to</label>
                    <asp:TextBox ID="f_WF3SignedOutTo" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (email)</label>
                    <asp:TextBox ID="f_WF3SignedOutToEmail" runat="server" />
                </div>
                <div class="f">
                    <label>Signed out to (old VDB)</label>
                    <asp:TextBox ID="f_WF3SignedOutToOld" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div id="secComments" runat="server" class="section">
            <div class="section-header">COMMENTS</div>
            <div class="section-body">
            <div class="hint" style="margin:-2px 0 10px;">Comments often cross-reference other file numbers and vault events.</div>
                <div class="fgrid">
                <div class="f f-wide">
                    <label>Comments</label>
                    <asp:TextBox ID="f_Comments" runat="server" TextMode="MultiLine" Rows="5" />
                </div>
                <div class="f f-wide">
                    <label>Additional comments</label>
                    <asp:TextBox ID="f_AdditionalComments" runat="server" TextMode="MultiLine" Rows="5" />
                </div>
                </div>
            </div>
        </div>

        <div id="secProv" runat="server" class="section">
            <div class="section-header">PROVENANCE</div>
            <div class="section-body">
            <div class="hint" style="margin:-2px 0 10px;">Read-only. Modified (old VDB) is the historically accurate activity date going back to 2009; SharePoint dates begin at the March 2022 bulk load.</div>
                <div class="fgrid">
                <div class="f f-num">
                    <label>Created in SharePoint</label>
                    <asp:TextBox ID="f_CreatedInSharePoint" runat="server" />
                </div>
                <div class="f">
                    <label>Created by</label>
                    <asp:TextBox ID="f_CreatedBy" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Modified in SharePoint</label>
                    <asp:TextBox ID="f_ModifiedInSharePoint" runat="server" />
                </div>
                <div class="f">
                    <label>Modified by</label>
                    <asp:TextBox ID="f_ModifiedBy" runat="server" />
                </div>
                <div class="f f-num">
                    <label>Modified (old VDB)</label>
                    <asp:TextBox ID="f_ModifiedOldVdb" runat="server" />
                </div>
                </div>
            </div>
        </div>

        <div class="detailbuttons">
            <asp:Button ID="btnSave" runat="server" Text="Save changes" CssClass="btn"
                OnClick="btnSave_Click" />
            <a class="btn btn-quiet" style="text-decoration:none;" href="Default.aspx">Back to search</a>
        </div>
        <div class="hint" id="roHint" runat="server" visible="false">
            You have read-only access. Contact IT to join the vault editors group
            if you maintain the register.
        </div>

    </div>
</asp:Content>
