# TO_SIMO_DO.md
- [ ] Widget for iPhone & MacOS
- [ ] I want to have in the log in page on both implementations ( mobile and desktop ) the original google logo on the sign in with google button ( as we did with apple ) 
- [ ] the image picker for the profile I want to change it from automatic to choosable from the user wich portion of the image to use
- [ ] For the desktop implementation what has been done with ollama is outstanding and I want to replicate the same thing also with LMStudio so the major local LLM providers are supported
- [ ] mobile animation between lateral scroll on the goals page? Improve it

## prompt to run
/grill-me  The current desktop AI coach implementation is almost perfect: 

* privacy mode: the user needs his own open router's API KEY;
* standard mode ( user connected with supabase ) uses my API KEY so the user doesn't need to care about that. The thing that needs to be implemented is that the user must have the pro subscription to access to the AI Coach. And in addition to that I see that inside the desktop app the paywall is not implemented  ( or at least it seems as when the pop up came out and I clicked on the button to see the plans it has redirected me to the settings in the profile page ). successfully ( as the mobile, where is fully working and professional ).

The mobile implementation is different ( and it's a problem ) as I want the implementations to be coherent as they are reppresenting the same app.

The mobile has already the paywall configured perfectly but the problem is the fact that the AI coach is accessible even from non pro users and it's a problem I want you to fix.