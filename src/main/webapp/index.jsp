<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width,initial-scale=1" />
	<title>NextWork — Welcome</title>
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
	<style>
		:root{
			--bg1:#0f172a;
			--bg2:#0b1220;
			--card:#0b1226cc;
			--accent:#6ee7b7;
			--muted:#9aa4b2;
			--glass: rgba(255,255,255,0.04);
			--radius:14px;
			--maxw:920px;
		}
		html,body{height:100%;margin:0;font-family:Inter,system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial;}
		body{
			background: radial-gradient(1200px 400px at 10% 10%, rgba(110,231,183,0.06), transparent 8%),
									linear-gradient(180deg,var(--bg1),var(--bg2));
			color:#e6eef7;display:flex;align-items:center;justify-content:center;padding:40px;
		}
		.wrap{width:100%;max-width:var(--maxw);}
		.card{
			display:grid;grid-template-columns:1fr 360px;gap:28px;background:linear-gradient(180deg, rgba(255,255,255,0.02), rgba(255,255,255,0.01));
			border-radius:var(--radius);padding:28px;box-shadow:0 6px 30px rgba(2,6,23,0.6);backdrop-filter: blur(6px);border:1px solid var(--glass);
		}
		.hero{padding:18px 12px}
		.logo{display:flex;align-items:center;gap:12px}
		.logo .mark{width:56px;height:56px;border-radius:12px;background:linear-gradient(135deg,var(--accent),#38bdf8);display:flex;align-items:center;justify-content:center;font-weight:700;color:#072127}
		h1{margin:10px 0 6px;font-size:22px;letter-spacing:-0.2px}
		p.lead{margin:0;color:var(--muted);line-height:1.6}
		.info{margin-top:18px;display:flex;flex-direction:column;gap:10px}
		.chip{display:inline-block;padding:8px 12px;background:rgba(255,255,255,0.03);border-radius:999px;color:var(--muted);font-size:13px}
		.actions{display:flex;gap:12px;margin-top:16px}
		.btn{padding:10px 14px;border-radius:10px;border:0;cursor:pointer;font-weight:600}
		.btn.primary{background:linear-gradient(90deg,var(--accent),#34d399);color:#03211a}
		.btn.ghost{background:transparent;border:1px solid rgba(255,255,255,0.06);color:var(--muted)}
		.sidebar{padding:18px;border-radius:12px;background:linear-gradient(180deg, rgba(255,255,255,0.015), rgba(255,255,255,0.01));align-self:start}
		.stat{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}
		.stat strong{font-size:18px}
		footer{margin-top:18px;color:var(--muted);font-size:13px}

		@media (max-width:880px){
			.card{grid-template-columns:1fr;}
			.sidebar{order:2}
		}
	</style>
</head>
<body>
	<div class="wrap">
		<div class="card" role="main">
			<div class="hero">
				<div class="logo">
					<div class="mark">NW</div>
					<div>
						<h1>Hello Adarsh RJ!</h1>
						<p class="lead">Welcome to your NextWork web application — deployment pipeline and repository updates are working.</p>
					</div>
				</div>

				<div class="info">
					<div class="chip">Automatically built & deployed</div>
					<p style="margin:0;color:var(--muted)">If you see this page, your latest changes were successfully pushed to GitHub and delivered via CodePipeline.</p>

					<div class="actions">
						<button class="btn primary" onclick="location.reload();">Refresh Preview</button>
						<button class="btn ghost" onclick="window.open('https://github.com','_blank')">Open Repository</button>
					</div>
				</div>

				<footer>Tip: Edit <code>src/main/webapp/index.jsp</code> and push to see updates.</footer>
			</div>

			<aside class="sidebar">
				<div class="stat"><div style="color:var(--muted)">Branch</div><strong>master</strong></div>
				<div class="stat"><div style="color:var(--muted)">CI</div><strong>CodePipeline</strong></div>
				<div class="stat"><div style="color:var(--muted)">Status</div><strong style="color:var(--accent)">Deployed</strong></div>
				<div style="height:1px;background:rgba(255,255,255,0.02);margin:12px 0;border-radius:2px"></div>
				<div style="color:var(--muted);font-size:13px;line-height:1.5">You can customize this page with your own styles, add a logo image, or link to live logs and metrics.</div>
			</aside>
		</div>
	</div>
</body>
</html>
