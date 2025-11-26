## Context

Below is a list of bugs and improvements that have yet to be addressed/fixed or implemented in the Electric Slideshow app. This list is in no particular order and is not exhaustive. It is to help track known issues and potential enhancements for future releases.

## Task

Please review the current codebase and review the following list of bugs and improvements I would like to implement. In this list, I want you to disregard any list items that are checked off, as those have already been addressed. For the remaining items, please assess the items and give your recommendations on what order you would recommend implementing them, and if there are any that you think should be prioritized over others. Then, please respond with the updated list, including any additional context or details that may be helpful for each item, and await further instructions. I will review your recommendations and then either ask you to implement the changes or provide further instructions or clarifications.

NOTE: Once I have approved your recommended order of implementation, I want you to provide me with instructions on how to implement each item, including any code snippets or changes that need to be made. I do not want you providing instructions for all unchecked items at once. You can group more than one item together if they can be implemented easily in one set of updates on my end. But please make note of that in your response (state which items are grouped together). I will then implement the changes and ask you to review them before moving on to the next set of items.

## Bugs and Improvements

- [ ] **Button/Clickable Elements UX**: Right now, the vast majority of buttons and clickable elements in the app do not have any visual feedback on hover. This includes the navbar buttons, slideshow cards, and almost every other interactive element. I would like to implement a consistent hover effect across all clickable cards (like slideshow cards and the cars/tiles in the app settings), suck as a border color change, shadow, or scale effect. And for all clickable elements and buttons, I would like the cursor to change to a pointer when hovering over them.

- [ ] **Now Playing View Improvements**: I want to update the slideshow UI/UX in the Now Playing view as follows:
  - [ ] When hovering over the slideshow photos, there are slideshow and music controls that appear and then disappear when there's no cursor activity for 3 seconds. I want these controls to be removed, including the 'X' button at the top left of the slideshow photo (that used to close the sheet that was playing the slideshow. But we aren't using a sheet anymore, so this button is no longer needed).
  - [ ] The only interaction with the slideshow photos should be clicking on the photo to pause/play the slideshow.
  - [ ] When a slideshow is paused, the music should also pause. When the slideshow is playing, the music should also play (and the music should continue playing where it left off when the slideshow was paused).
  - [ ] Interactions with the music controls should have no effect on the slideshow playback. The music controls should only control the music playback, not the slideshow. So skipping tracks, pausing, and changing the volume should only affect the music playback, not the slideshow.
  - [ ] When a slideshow is paused, there should be some sort of visual indication that the slideshow is paused, such as a play/pause icon overlay on the photo or a pause icon in the bottom bar or navbar. Whichever you think is best.
  - [ ] Right now, the bottom bar has the elements/buttons in place for controlling the slideshow, as well as the elements/buttons in place for controlling the music playlist for the current slideshow. However, the functionality for them isn't implemented yet. They're currently just placeholders. I want them updated to be functional controls for the slideshow and music playback.