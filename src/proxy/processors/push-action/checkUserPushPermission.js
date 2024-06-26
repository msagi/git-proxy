const Step = require('../../actions').Step;
const db = require('../../../db');

// Execute if the repo is approved
const exec = async (req, action) => {
  const step = new Step('checkUserPushPermission');

  const repoUrl = action.repo.url;
  let isUserAllowed = false;
  let user = action.user;

  // Find the user associated with this Git Account
  const list = await db.getUsers({ gitAccount: action.user });

  console.log(JSON.stringify(list));

  if (list.length == 1) {
    user = list[0].username;
    isUserAllowed = await db.isUserPushAllowed(repoUrl, user);
  }

  console.log(`User '${user}' permission on Repo '${repoUrl}' : '${isUserAllowed}'`);

  if (!isUserAllowed) {
    console.log('User not allowed to Push');
    step.error = true;
    step.log(`User '${user}' is not allowed to push on repo '${action.repo.url}', ending`);

    console.log('setting error');

    step.setError(
      `Rejecting push as user '${action.user}' ` +
        `is not allowed to push on repo ` +
        `'${action.repo.url}'`,
    );
    action.addStep(step);
    return action;
  }

  step.log(`User '${user}' is allowed to push on repo '${action.repo.url}'`);
  action.addStep(step);
  return action;
};

exec.displayName = 'checkUserPushPermission.exec';
exports.exec = exec;
