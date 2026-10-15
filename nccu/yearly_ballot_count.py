import pandas as pd
import matplotlib.pyplot as plt

plt.close("all")

df = pd.read_csv("data/processed/nccu_yearly_summary.csv")
df["year"] = df["year"].astype(int)

# "under25" / "all" from the first version of the table, "18to24" / "all_18plus" if you re-ran the 18+ version
u = df[df["age_group"].isin(["under25", "18to24"])].set_index("year").sort_index()
a = df[df["age_group"].isin(["all", "all_18plus"])].set_index("year").sort_index()

num = u["undeliverable"]  # under-25 undeliverable voters
den = a["total_ballots_cast"]  # total ballots cast, all ages
# den = u["total_ballots_cast"]     # <- use this line instead for under-25 ballots only
pct = num / den * 100

fig, ax = plt.subplots(figsize=(8, 4.5))
ax.set_axisbelow(True)
ax.bar(pct.index.astype(str), pct, width=0.6, color="tab:red")

for i, year in enumerate(pct.index):
    ax.annotate(
        f"{pct[year]:.1f}%\n({int(num[year]):,} / {int(den[year]):,})",
        (i, pct[year]),
        textcoords="offset points",
        xytext=(0, 4),
        ha="center",
        fontsize=9,
    )

ax.set_xlabel("Election")
ax.set_ylabel("Under-25 undeliverable voters\nas % of total ballots cast")
ax.set_title(
    "Under-25 undeliverable voters relative to total ballots cast\n"
    "precincts 55-49 and 55-11",
    fontsize=11,
)
ax.set_ylim(0, pct.max() * 1.3)
ax.grid(axis="y", alpha=0.3)

plt.tight_layout()
plt.savefig(
    "data/processed/nccu_u25_undeliverable_ratio.png", dpi=200, bbox_inches="tight"
)
plt.show()

print(
    pd.DataFrame({"u25_undeliverable": num, "total_ballots": den, "pct": pct.round(2)})
)

# creating youth casted and thrown visualization

plt.close("all")  # clear leftover figures from earlier runs

df = pd.read_csv("data/processed/nccu_yearly_summary.csv")
df["year"] = df["year"].astype(int)

# "under25" from the first version of the table, "18to24" if you re-ran the 18+ version
u = df[df["age_group"].isin(["under25", "18to24"])].set_index("year").sort_index()
k = df[df["age_group"] == "unknown"].set_index("year").sort_index()

# upper-bound estimate: under 25 + unknown
est = (
    u[["total_ballots_cast", "provisional_cast"]]
    .add(k[["total_ballots_cast", "provisional_cast"]], fill_value=0)
    .astype(int)
)

LIGHT_GRAY = "#dadada"

lines = [
    (
        u,
        "total_ballots_cast",
        "Ballots cast (confirmed under 25)",
        "tab:blue",
        "-",
        "o",
        3,
    ),
    (
        u,
        "provisional_cast",
        "Provisional ballots cast (confirmed under 25)",
        "tab:blue",
        "--",
        "s",
        3,
    ),
    (
        est,
        "total_ballots_cast",
        "Ballots cast (under 25 + unknown)",
        LIGHT_GRAY,
        "-",
        "o",
        1,
    ),
    (
        est,
        "provisional_cast",
        "Provisional ballots cast (under 25 + unknown)",
        LIGHT_GRAY,
        "--",
        "s",
        1,
    ),
]

fig, ax = plt.subplots(figsize=(8, 4.5))
ax.set_axisbelow(True)  # keeps the grid behind all the lines

for data, col, label, color, ls, marker, z in lines:
    ax.plot(
        data.index, data[col], marker=marker, color=color, ls=ls, label=label, zorder=z
    )
    if color == LIGHT_GRAY:
        continue  # no number labels on the gray lines
    for x, y in zip(data.index, data[col]):
        ax.annotate(
            f"{y:,}",
            (x, y),
            textcoords="offset points",
            xytext=(0, 7),
            ha="center",
            fontsize=8,
            color=color,
            zorder=4,
        )

ax.set_xticks(u.index)
ax.set_xlabel("Election")
ax.set_ylabel("Number of ballots")
ax.set_title(
    "Under-25 voters: confirmed vs. upper-bound estimate (including unknown ages)\n"
    "precincts 55-49 and 55-11",
    fontsize=11,
)
ax.set_ylim(bottom=0)
ax.grid(alpha=0.3)
ax.legend(fontsize=8)

plt.tight_layout()
plt.savefig("data/processed/nccu_under25_estimate.png", dpi=200, bbox_inches="tight")
plt.show()

print(est)  # exact values for the gray lines
