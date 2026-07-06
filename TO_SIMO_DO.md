# TO_SIMO_DO.md
- [ ] Local AI Models ( Ollama for desktop? Other solutions? For mobile what can we do? )
- [x] Redesign the box of the montly calendar view in the home page as inside the box there are some wird boxes that appears when I start logging habits but I want a much more professional look ( even without anythiing but leaving a personalized color based on the performance is fine if there aren't other solutions ) (done 2026-07-06 — removed the per-habit dots; day cell is now a centered number over the performance color)

## DESKTOP
- [ ] Privacy policy in the log in must be a small icon;
- [ ] When I click on a long term goal there must be a delay of 2 seconds before the goals move to done; If I click to times on it before the 2 seconds elapses the goal should go to failed, if I click another time it should go to back as open ( not failed and not completed );
- [ ] Tutorial;

## MOBILE
- [x] Profile photo when updated from the settings it becames black in the other pages and does not render the users' photo; (fixed 2026-07-06 — dashboard header used NetworkImage on a local path; now a shared ProfileAvatarImage widget)
- [x] Change the bar in the month from the dashboard as right now are colored in a specific color but I would love to have them to have a performance base color like we have in the home page in the monthly view ( based on the completed and failed habits ). If the current implementation is not the best we can also decide to implement a new professional one that allignes better with this goal; (done 2026-07-06 — yearly-view month bars now use the shared performance color scale; also fixed the completion metric to count only habits active that day)

---

fastlane ios update_notes
