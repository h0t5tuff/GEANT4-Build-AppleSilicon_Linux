

/*detector is a single small-ish HPGe-like volume with no surrounding materials, no cryostat, no
 * dead layers, no LAr, no other detectors.*/


#include <iostream>
#include <map>

#include "TCanvas.h"
#include "TDirectory.h"
#include "TFile.h"
#include "TH1D.h"
#include "TTree.h"

void TensorsMacros_sum_edep() {

  const char* file0 = "decay0_0vbb_250k.root";
  const char* file2 = "decay0_2vbb_250k.root";

  const char* treename = "det001";
  const char* edep_branch = "edep_in_keV";
  const char* event_branch = "evtid";

  auto make_hist = [&](const char* fname, Color_t color) {
    TFile f(fname, "READ");
    if (f.IsZombie()) {
      std::cerr << "Cannot open " << fname << "\n";
      return (TH1D*)nullptr;
    }

    TDirectory* d = f.GetDirectory("stp");
    if (!d) {
      std::cerr << "No stp/ in " << fname << "\n";
      return (TH1D*)nullptr;
    }

    TTree* t = (TTree*)d->Get(treename);
    if (!t) {
      std::cerr << "No tree stp/" << treename << " in " << fname << "\n";
      return (TH1D*)nullptr;
    }

    Double_t edep = 0.0;
    Int_t evtid = 0;

    t->SetBranchAddress(edep_branch, &edep);
    t->SetBranchAddress(event_branch, &evtid);

    std::map<int, double> E;
    const Long64_t n = t->GetEntries();
    for (Long64_t i = 0; i < n; i++) {
      t->GetEntry(i);
      E[evtid] += edep;
    }

    auto h = new TH1D(Form("E_%s", fname), ";Total deposited energy [keV];Events", 3000, 0, 3000);
    h->SetDirectory(nullptr);
    h->SetLineColor(color);
    h->SetLineWidth(2);

    for (auto& kv : E) h->Fill(kv.second);

    return h;
  };

  auto h0 = make_hist(file0, kRed + 1);
  auto h2 = make_hist(file2, kBlue + 1);

  if (!h0 || !h2) {
    std::cerr << "Histogram creation failed\n";
    return;
  }

  auto c = new TCanvas("c1", "0vbb vs 2vbb", 900, 700);
  h0->Draw("HIST");
  h2->Draw("HIST SAME");

  c->Update();
}
